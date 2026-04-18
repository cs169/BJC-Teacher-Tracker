# frozen_string_literal: true

require "json"

class AwsSnsNotificationHandler
  class ProcessingError < StandardError; end

  def initialize(envelope)
    @envelope = envelope
  end

  def call
    case envelope.fetch("Type")
    when "SubscriptionConfirmation"
      confirm_subscription!
    when "Notification"
      process_notification!
    else
      raise ProcessingError, "Unsupported SNS notification type"
    end
  end

  private
  attr_reader :envelope

  def confirm_subscription!
    subscribe_url = envelope["SubscribeURL"].to_s
    raise ProcessingError, "Missing SubscribeURL" if subscribe_url.blank?

    response = HTTParty.get(subscribe_url)
    raise ProcessingError, "Subscription confirmation failed" unless response.success?
  end

  def process_notification!
    ses_event = JSON.parse(envelope.fetch("Message"))
    AwsSesEventProcessor.new(
      sns_message_id: envelope.fetch("MessageId"),
      topic_arn: envelope["TopicArn"],
      ses_event:
    ).call
  end
end