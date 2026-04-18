# frozen_string_literal: true

class AwsSnsNotificationHandler
  class ProcessingError < StandardError; end

  def initialize(envelope)
    @envelope = envelope
  end

  def call
    case envelope.fetch("Type")
    when "SubscriptionConfirmation"
      url = envelope["SubscribeURL"].to_s
      raise ProcessingError, "Missing SubscribeURL" if url.blank?
      raise ProcessingError, "Subscription confirmation failed" unless HTTParty.get(url).success?
    when "Notification"
      AwsSesEventProcessor.new(
        sns_message_id: envelope.fetch("MessageId"),
        topic_arn: envelope["TopicArn"],
        ses_event: JSON.parse(envelope.fetch("Message"))
      ).call
    else
      raise ProcessingError, "Unsupported SNS notification type"
    end
  end

  private
  attr_reader :envelope
end