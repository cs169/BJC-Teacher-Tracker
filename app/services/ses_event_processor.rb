# frozen_string_literal: true

class SesEventProcessor
  class ProcessingError < StandardError; end

  PROCESSABLE_EVENT_TYPES = %w[Send Delivery Bounce Complaint].freeze

  def initialize(ses_event, sns_message_id:)
    @ses_event = ses_event
    @sns_message_id = sns_message_id
  end

  def call
    return unless PROCESSABLE_EVENT_TYPES.include?(event_type)

    recipient_emails.each do |recipient|
      process_recipient(recipient)
    end
  end

  private
  attr_reader :ses_event, :sns_message_id

  def event_type
    ses_event["eventType"]
  end

  def recipient_emails
    case event_type
    when "Bounce"
      Array(ses_event.dig("bounce", "bouncedRecipients")).filter_map { |r| r["emailAddress"] }
    when "Complaint"
      Array(ses_event.dig("complaint", "complainedRecipients")).filter_map { |r| r["emailAddress"] }
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
      event.save!
    rescue ActiveRecord::RecordNotUnique
      # Idempotent: this (sns_message_id, recipient_email) pair was already processed.
      return
    end

    apply_counters(email_address) if email_address
  end

  def apply_counters(email_address)
    updates = { last_ses_event_at: Time.current }

    case event_type
    when "Send"
      updates[:emails_sent] = email_address.emails_sent + 1
    when "Delivery"
      updates[:emails_delivered] = email_address.emails_delivered + 1
    when "Bounce"
      if ses_event.dig("bounce", "bounceType") == "Transient"
        updates[:soft_bounce_count] = email_address.soft_bounce_count + 1
      else
        updates[:hard_bounce_count] = email_address.hard_bounce_count + 1
        updates[:bounced] = true
      end
    when "Complaint"
      updates[:hard_bounce_count] = email_address.hard_bounce_count + 1
      updates[:bounced] = true
    end

    email_address.update_columns(updates)
  end

  def event_occurred_at
    timestamp =
      ses_event.dig("delivery", "timestamp") ||
      ses_event.dig("bounce", "timestamp") ||
      ses_event.dig("complaint", "timestamp") ||
      ses_event.dig("mail", "timestamp")

    return Time.current if timestamp.blank?
    Time.parse(timestamp)
  rescue ArgumentError
    Time.current
  end
end
