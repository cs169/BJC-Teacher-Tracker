# frozen_string_literal: true

Rails.application.config.after_initialize do
  if ENV["SNS_ALLOWED_TOPIC_ARNS"].to_s.strip.empty? && !Rails.env.test?
    Rails.logger.warn("[SNS Webhook] SNS_ALLOWED_TOPIC_ARNS is not set. The SES webhook will reject all incoming messages.")
  end
end
