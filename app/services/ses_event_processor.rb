# frozen_string_literal: true

class SesEventProcessor
  class ProcessingError < StandardError; end

  PROCESSABLE_EVENT_TYPES = %w[Send Delivery Bounce Complaint].freeze

  def initialize(ses_event, sns_message_id:)
    @ses_event = ses_event
    @sns_message_id = sns_message_id
  end

  def call
    raise ProcessingError, "SES event must be a Hash, got #{ses_event.class}" unless ses_event.is_a?(Hash)

    unless PROCESSABLE_EVENT_TYPES.include?(event_type)
      Rails.logger.info("[SES Webhook] Skipping SES event type #{event_type.inspect} (sns_message_id=#{sns_message_id})")
      return
    end

    recipient_emails.each do |recipient|
      process_recipient(recipient)
    end
  rescue TypeError, ActiveRecord::RecordInvalid => e
    # Signed by SNS but not shaped like an SES event (e.g. "bounce" is a string,
    # or the envelope had no MessageId).
    raise ProcessingError, "Unexpected SES event shape: #{e.message}"
  end

  private
  attr_reader :ses_event, :sns_message_id

  # Configuration-set event publishing sends "eventType"; identity feedback
  # notifications (Bounce/Complaint/Delivery only) send "notificationType" with
  # the same "mail"/"bounce"/"complaint"/"delivery" sub-objects. Accept either.
  def event_type
    ses_event["eventType"] || ses_event["notificationType"]
  end

  def recipient_emails
    case event_type
    when "Bounce"
      Array(ses_event.dig("bounce", "bouncedRecipients")).filter_map { |r| r["emailAddress"] if r.is_a?(Hash) }
    when "Complaint"
      Array(ses_event.dig("complaint", "complainedRecipients")).filter_map { |r| r["emailAddress"] if r.is_a?(Hash) }
    when "Delivery"
      # mail.destination lists every To/CC/BCC address, including ones that
      # bounced or were delivered in a separate event. Only count the
      # recipients this delivery covers.
      Array(ses_event.dig("delivery", "recipients"))
    else
      Array(ses_event.dig("mail", "destination"))
    end
  end

  def process_recipient(recipient_email)
    normalized = recipient_email.to_s.strip.downcase
    return if normalized.empty?

    email_address = EmailAddress.find_by(email: normalized)

    event = SesDeliveryEvent.new(
      email_address:,
      sns_message_id:,
      event_type:,
      bounce_type: ses_event.dig("bounce", "bounceType"),
      recipient_email: normalized,
      event_occurred_at:,
      payload: ses_event
    )

    begin
      SesDeliveryEvent.transaction do
        event.save!
        apply_counters(email_address) if email_address
      end
    rescue ActiveRecord::RecordNotUnique
      # Idempotent: this (sns_message_id, recipient_email) pair was already processed.
      nil
    end
  end

  # Increments happen in SQL (col = col + 1) so concurrent webhook requests for
  # the same address can't lose updates, and they share a transaction with the
  # event insert so the dedupe row and the counter bump commit together.
  def apply_counters(email_address)
    counter_columns = []

    case event_type
    when "Send"
      counter_columns << "emails_sent"
    when "Delivery"
      counter_columns << "emails_delivered"
    when "Bounce"
      if ses_event.dig("bounce", "bounceType") == "Transient"
        counter_columns << "soft_bounce_count"
      else
        counter_columns << "hard_bounce_count"
      end
    when "Complaint"
      # TODO: complaints are counted as hard bounces for now (they do mean
      # "stop emailing this address"). Tracking them separately needs a new
      # complaint_count column; the raw events are in ses_delivery_events.
      counter_columns << "hard_bounce_count"
    end

    assignments = counter_columns.map { |col| "#{col} = #{col} + 1" }
    assignments << "bounced = TRUE" if marks_bounced?
    assignments << "last_ses_event_at = :now"

    EmailAddress.where(id: email_address.id)
                .update_all([assignments.join(", "), { now: Time.current }])
  end

  def marks_bounced?
    case event_type
    when "Bounce" then ses_event.dig("bounce", "bounceType") != "Transient"
    when "Complaint" then true
    else false
    end
  end

  def event_occurred_at
    timestamp =
      ses_event.dig("delivery", "timestamp") ||
      ses_event.dig("bounce", "timestamp") ||
      ses_event.dig("complaint", "timestamp") ||
      ses_event.dig("mail", "timestamp")

    return Time.current if timestamp.blank?
    Time.parse(timestamp.to_s)
  rescue ArgumentError
    Time.current
  end
end
