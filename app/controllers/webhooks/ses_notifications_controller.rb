# frozen_string_literal: true

module Webhooks
  class SesNotificationsController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      envelope = SnsMessageVerifier.verify!(request.raw_post)

      case envelope["Type"]
      when "SubscriptionConfirmation"
        SnsSubscriptionConfirmer.confirm!(envelope["SubscribeURL"])
      when "Notification"
        ses_event = JSON.parse(envelope["Message"])
        SesEventProcessor.new(ses_event, sns_message_id: envelope["MessageId"]).call
      when "UnsubscribeConfirmation"
        Rails.logger.info("[SES Webhook] UnsubscribeConfirmation for #{envelope["TopicArn"]}")
      else
        Rails.logger.warn("[SES Webhook] Unknown SNS message Type: #{envelope["Type"].inspect}")
      end

      head :no_content
    rescue SnsMessageVerifier::VerificationError => e
      Rails.logger.warn("[SES Webhook] Verification failed: #{e.message}")
      head :unauthorized
    rescue JSON::ParserError, SesEventProcessor::ProcessingError, SnsSubscriptionConfirmer::ConfirmationError => e
      Rails.logger.warn("[SES Webhook] #{e.class}: #{e.message}")
      head :bad_request
    end
  end
end
