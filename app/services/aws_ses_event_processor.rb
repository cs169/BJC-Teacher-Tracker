# frozen_string_literal: true

class AwsSesEventProcessor
  APP_TAG_KEY = "app"
  APP_TAG_VALUE = "bjc_teacher_tracker"
  KNOWN_EVENT_TYPES = %w[send delivery bounce complaint reject renderingfailure deliverydelay].to_set.freeze

  def initialize(sns_message_id:, topic_arn:, ses_event:)
    @sns_message_id = sns_message_id
    @topic_arn = topic_arn
    @ses_event = ses_event
  end

  def call
    return 0 unless relevant_message?
    recipients.count { |email| process_recipient(email) }
  end

  private
  attr_reader :sns_message_id, :topic_arn, :ses_event

  def process_recipient(recipient_email)
    email_address = EmailAddress.find_by(email: recipient_email)
    teacher = email_address&.teacher || tagged_teacher

    event = EmailDeliveryEvent.find_or_initialize_by(
      provider: "aws_ses", sns_message_id:, recipient_email:
    )
    return false if event.persisted?

    event.update!(
      email_address:, teacher:,
      ses_message_id: mail["messageId"],
      event_type: event_type,
      mailer_action: tag("mailer_action"),
      bounce_type: detail["bounceType"],
      bounce_sub_type: detail["bounceSubType"],
      complaint_feedback_type: detail["complaintFeedbackType"],
      event_occurred_at: Time.zone.parse((detail["timestamp"] || mail["timestamp"]).to_s),
      message_tags: mail["tags"] || {},
      payload: ses_event
    )

    email_address&.recalculate_deliverability!
    SyncTeacherToMailblusterJob.perform_later(teacher.id) if teacher && email_address&.primary? && event.suppresses_address?
    true
  end

  def relevant_message?
    return false if event_type.blank?

    app_tag = Array(mail.dig("tags", APP_TAG_KEY)).first
    return true if app_tag == APP_TAG_VALUE

    config_set = ENV["AWS_SES_CONFIGURATION_SET"].to_s
    config_set.present? && Array(mail.dig("tags", "ses:configuration-set")).include?(config_set)
  end

  def recipients
    raw = case event_type
          when "bounce"    then Array(detail["bouncedRecipients"]).map { |r| r["emailAddress"] }
          when "complaint" then Array(detail["complainedRecipients"]).map { |r| r["emailAddress"] }
          when "delivery"  then Array(detail["recipients"])
          else                  Array(mail["destination"])
          end
    raw.filter_map { |e| e.to_s.strip.downcase.presence }.uniq
  end

  def event_type
    @event_type ||= begin
      raw = (ses_event["eventType"] || ses_event["notificationType"]).to_s.downcase.delete(" ")
      raw if KNOWN_EVENT_TYPES.include?(raw)
    end
  end

  def mail
    ses_event.fetch("mail")
  end

  def detail
    @detail ||= ses_event.fetch(event_type, {})
  end

  def tagged_teacher
    id = tag("teacher_id")
    Teacher.find_by(id: id) if id.present?
  end

  def tag(key)
    Array(mail.dig("tags", key)).first
  end
end