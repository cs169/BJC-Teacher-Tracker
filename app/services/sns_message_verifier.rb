# frozen_string_literal: true

require "aws-sdk-sns"

class SnsMessageVerifier
  class VerificationError < StandardError; end

  def self.verify!(raw_body)
    new(raw_body).verify!
  end

  def initialize(raw_body)
    @raw_body = raw_body
  end

  def verify!
    envelope = parse_envelope
    assert_topic_allowed!(envelope["TopicArn"])
    assert_signature_valid!(envelope)
    envelope
  end

  private
  attr_reader :raw_body

  def parse_envelope
    JSON.parse(raw_body)
  rescue JSON::ParserError => e
    raise VerificationError, "Invalid JSON: #{e.message}"
  end

  def assert_topic_allowed!(topic_arn)
    return if topic_arn.present? && allowed_topic_arns.include?(topic_arn)
    raise VerificationError, "Topic ARN #{topic_arn.inspect} is not in the allowlist"
  end

  def assert_signature_valid!(envelope)
    Aws::SNS::MessageVerifier.new.authenticate!(envelope.to_json)
  rescue Aws::SNS::MessageVerifier::VerificationError => e
    raise VerificationError, "Signature verification failed: #{e.message}"
  end

  def allowed_topic_arns
    (ENV["SNS_ALLOWED_TOPIC_ARNS"] || "").split(",").map(&:strip).reject(&:empty?)
  end
end
