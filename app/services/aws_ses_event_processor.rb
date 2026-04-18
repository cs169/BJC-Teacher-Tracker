# frozen_string_literal: true

require "json"

class AwsSesEventProcessor
  APP_TAG_KEY = "app"
  APP_TAG_VALUE = "bjc_teacher_tracker"

  EVENT_TYPE_ALIASES = {
    "send" => "send",
    "delivery" => "delivery",
    "bounce" => "bounce",
    "complaint" => "complaint",
    "reject" => "reject",
    "rendering failure" => "renderingfailure",
    "renderingfailure" => "renderingfailure",
    "delivery delay" => "deliverydelay",
    "deliverydelay" => "deliverydelay"
  }.freeze

  def initialize(sns_message_id:, topic_arn:, ses_event:)
    @sns_message_id = sns_message_id
    @topic_arn = topic_arn
    @ses_event = ses_event
  end

  def call
    return 0 unless relevant_message?

    recipients.sum { |recipient_email| upsert_event_for(recipient_email) ? 1 : 0 }
  end

  private
  attr_reader :sns_message_id, :topic_arn, :ses_event

  def upsert_event_for(recipient_email)
    email_address = EmailAddress.find_by(email: recipient_email)
    teacher = email_address&.teacher || tagged_teacher

    event = EmailDeliveryEvent.find_or_initialize_by(
      provider: "aws_ses",
      sns_message_id:,
      recipient_email:
    )

    return false if event.persisted?

    event.assign_attributes(
      email_address:,
      teacher:,
      ses_message_id: mail_payload["messageId"],
      event_type: normalized_event_type,
      mailer_action: tag_value("mailer_action"),
      bounce_type: bounce_payload["bounceType"],
      bounce_sub_type: bounce_payload["bounceSubType"],
      complaint_feedback_type: complaint_payload["complaintFeedbackType"],
      event_occurred_at: occurred_at,
      message_tags: mail_payload["tags"] || {},
      payload: ses_event
    )
    event.save!

    email_address&.recalculate_deliverability!
    enqueue_mailbluster_sync(email_address, teacher, event)
    true
  end

  def relevant_message?
    return false if normalized_event_type.blank?

    app_tag = Array(mail_payload.dig("tags", APP_TAG_KEY)).first
    return true if app_tag == APP_TAG_VALUE

    configuration_set = ENV["AWS_SES_CONFIGURATION_SET"].to_s
    return false if configuration_set.blank?

    Array(mail_payload.dig("tags", "ses:configuration-set")).include?(configuration_set)
  end

  def recipients
    extracted = case normalized_event_type
    when "bounce"
      Array(bounce_payload["bouncedRecipients"]).map { |recipient| recipient["emailAddress"] }
    when "complaint"
      Array(complaint_payload["complainedRecipients"]).map { |recipient| recipient["emailAddress"] }
    when "delivery"
      Array(delivery_payload["recipients"])
    else
      Array(mail_payload["destination"])
    end

    extracted.map { |email| email.to_s.strip.downcase }.reject(&:blank?).uniq
  end

  def occurred_at
    timestamp = case normalized_event_type
    when "bounce"
      bounce_payload["timestamp"]
    when "complaint"
      complaint_payload["timestamp"]
    when "delivery"
      delivery_payload["timestamp"]
    else
      mail_payload["timestamp"]
    end

    Time.zone.parse(timestamp.to_s)
  end

  def normalized_event_type
    @normalized_event_type ||= begin
      raw_type = ses_event["eventType"].presence || ses_event["notificationType"].presence
      EVENT_TYPE_ALIASES[raw_type.to_s.downcase]
    end
  end

  def mail_payload
    ses_event.fetch("mail")
  end

  def bounce_payload
    ses_event.fetch("bounce", {})
  end

  def complaint_payload
    ses_event.fetch("complaint", {})
  end

  def delivery_payload
    ses_event.fetch("delivery", {})
  end

  def tagged_teacher
    teacher_id = tag_value("teacher_id")
    return if teacher_id.blank?

    Teacher.find_by(id: teacher_id)
  end

  def tag_value(key)
    Array(mail_payload.dig("tags", key)).first
  end

  def enqueue_mailbluster_sync(email_address, teacher, event)
    return unless teacher
    return unless email_address&.primary?
    return unless event.suppresses_address?

    SyncTeacherToMailblusterJob.perform_later(teacher.id)
  end
end