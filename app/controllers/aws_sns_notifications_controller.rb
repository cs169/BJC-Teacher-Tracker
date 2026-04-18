# frozen_string_literal: true

class AwsSnsNotificationsController < ActionController::Base
  protect_from_forgery with: :null_session

  def create
    raw_body = request.raw_post
    envelope = AwsSnsMessageVerifier.verify!(raw_body)
    AwsSnsNotificationHandler.new(envelope).call

    head :no_content
  rescue AwsSnsMessageVerifier::VerificationError => e
    Rails.logger.warn("[AWS SNS] Verification failed: #{e.message}")
    head :unauthorized
  rescue AwsSnsNotificationHandler::ProcessingError, JSON::ParserError => e
    Rails.logger.warn("[AWS SNS] Invalid notification: #{e.message}")
    head :bad_request
  end
end