# frozen_string_literal: true

module Webhooks
  # Public endpoint for AWS SNS → SES delivery events. See "SES bounce tracking"
  # in the README for setup. Every response here is deliberately terse: the
  # caller is unauthenticated until SnsMessageVerifier succeeds.
  class SesNotificationsController < ActionController::Base
    protect_from_forgery with: :null_session

    # SNS messages are capped at 256 KB.
    MAX_BODY_BYTES = 256.kilobytes

    def create
      return head(:payload_too_large) if body_too_large?

      envelope = SnsMessageVerifier.verify!(request.raw_post)

      case envelope["Type"]
      when "SubscriptionConfirmation"
        SnsSubscriptionConfirmer.confirm!(envelope["SubscribeURL"])
      when "Notification"
        process_notification(envelope)
      when "UnsubscribeConfirmation"
        Rails.logger.info("[SES Webhook] UnsubscribeConfirmation for #{envelope["TopicArn"]}")
      else
        Rails.logger.warn("[SES Webhook] Unknown SNS message Type: #{envelope["Type"].inspect}")
      end

      head :no_content
    rescue SnsMessageVerifier::MalformedEnvelopeError => e
      Rails.logger.warn("[SES Webhook] Malformed envelope: #{e.message}")
      head :bad_request
    rescue SnsMessageVerifier::VerificationError => e
      Rails.logger.warn("[SES Webhook] Verification failed: #{e.message}")
      head :unauthorized
    rescue SnsSubscriptionConfirmer::NetworkError => e
      # Transient: a 5xx makes SNS retry the confirmation later.
      Rails.logger.error("[SES Webhook] Could not reach SubscribeURL: #{e.message}")
      head :service_unavailable
    rescue JSON::ParserError, SesEventProcessor::ProcessingError, SnsSubscriptionConfirmer::ConfirmationError => e
      Rails.logger.warn("[SES Webhook] #{e.class}: #{e.message}")
      head :bad_request
    end

    private
    def body_too_large?
      request.content_length.to_i > MAX_BODY_BYTES || request.raw_post.to_s.bytesize > MAX_BODY_BYTES
    end

    def process_notification(envelope)
      message = envelope["Message"]
      ses_event = message.is_a?(String) ? JSON.parse(message) : nil

      unless ses_event.is_a?(Hash)
        # Signed by SNS but not an SES event object (e.g. a test publish from the
        # console). Nothing to do; 2xx so SNS doesn't retry it.
        Rails.logger.warn("[SES Webhook] Ignoring Notification #{envelope["MessageId"].inspect}: Message is not a JSON object")
        return
      end

      SesEventProcessor.new(ses_event, sns_message_id: envelope["MessageId"]).call
    end
  end
end
