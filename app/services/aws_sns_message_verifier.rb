# frozen_string_literal: true

require "aws-sdk-sns"

class AwsSnsMessageVerifier
  class VerificationError < StandardError; end

  class << self
    def verify!(raw_body)
      verifier.authenticate!(raw_body)
      envelope = JSON.parse(raw_body)
      validate_topic_arn!(envelope)
      envelope
    rescue Aws::SNS::MessageVerifier::VerificationError => e
      raise VerificationError, e.message
    end

    private
    def verifier
      @verifier ||= Aws::SNS::MessageVerifier.new
    end

    def validate_topic_arn!(envelope)
      return if allowed_topic_arns.empty?
      return if allowed_topic_arns.include?(envelope["TopicArn"])

      raise VerificationError, "Unexpected SNS topic"
    end

    def allowed_topic_arns
      ENV.fetch("AWS_SNS_TOPIC_ARNS", "")
        .split(",")
        .map(&:strip)
        .reject(&:blank?)
    end
  end
end