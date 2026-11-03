# frozen_string_literal: true

require "aws-sdk-sns"

class SnsMessageVerifier
  class VerificationError < StandardError; end
  # The body is not a JSON object at all. Raised before any signature check, so
  # the controller can answer 400 instead of 401.
  class MalformedEnvelopeError < VerificationError; end

  # Real AWS signing certs look like
  #   https://sns.us-west-2.amazonaws.com/SimpleNotificationService-<hex>.pem
  # We check this before the SDK sees the envelope, because the SDK downloads
  # the URL (and caches it forever) before checking any signature. Anchored and
  # matched against the raw string, so ports, userinfo, queries and fragments
  # are all rejected.
  SIGNING_CERT_URL_PATTERN = %r{\Ahttps://sns\.([a-z0-9-]+)\.amazonaws\.com/SimpleNotificationService-[a-f0-9]+\.pem\z}
  TOPIC_ARN_REGION_PATTERN = /\Aarn:aws:sns:([a-z0-9-]+):/

  AWS_VERIFIER_LOCK = Mutex.new
  private_constant :AWS_VERIFIER_LOCK

  def self.verify!(raw_body)
    new(raw_body).verify!
  end

  # One shared SDK verifier for the whole process. The SDK caches downloaded
  # signing certificates by SigningCertURL on the instance, so reusing it means
  # we only fetch each AWS cert once (lazily, on the first message that uses it)
  # instead of on every request.
  def self.aws_verifier
    AWS_VERIFIER_LOCK.synchronize do
      @aws_verifier ||= Aws::SNS::MessageVerifier.new
    end
  end

  # Test helper: drop the memoized verifier (and its cert cache).
  def self.reset_aws_verifier!
    AWS_VERIFIER_LOCK.synchronize { @aws_verifier = nil }
  end

  def initialize(raw_body)
    @raw_body = raw_body
  end

  def verify!
    envelope = parse_envelope
    assert_topic_allowed!(envelope["TopicArn"])
    assert_signing_cert_url_valid!(envelope["SigningCertURL"], envelope["TopicArn"])
    assert_signature_valid!(envelope)
    envelope
  end

  private
  attr_reader :raw_body

  def parse_envelope
    envelope = JSON.parse(raw_body.to_s)
    raise MalformedEnvelopeError, "Envelope must be a JSON object, got #{envelope.class}" unless envelope.is_a?(Hash)
    envelope
  rescue JSON::ParserError => e
    raise MalformedEnvelopeError, "Invalid JSON: #{e.message}"
  end

  def assert_topic_allowed!(topic_arn)
    return if topic_arn.present? && allowed_topic_arns.include?(topic_arn)
    raise VerificationError, "Topic ARN #{topic_arn.inspect} is not in the allowlist"
  end

  def assert_signing_cert_url_valid!(cert_url, topic_arn)
    cert_region = cert_url.is_a?(String) && cert_url[SIGNING_CERT_URL_PATTERN, 1]
    topic_region = topic_arn.to_s[TOPIC_ARN_REGION_PATTERN, 1]
    return if cert_region && cert_region == topic_region
    raise VerificationError, "SigningCertURL #{cert_url.to_s.truncate(200).inspect} is not a valid SNS cert URL for this topic"
  end

  def assert_signature_valid!(envelope)
    self.class.aws_verifier.authenticate!(envelope.to_json)
  rescue Aws::SNS::MessageVerifier::VerificationError => e
    raise VerificationError, "Signature verification failed: #{e.message}"
  rescue StandardError => e
    # Missing/garbled fields (e.g. no SigningCertURL, non-string Signature) make
    # the SDK raise URI/Type/OpenSSL errors. Any of those means "not verified".
    raise VerificationError, "Signature verification failed (#{e.class}): #{e.message}"
  end

  def allowed_topic_arns
    (ENV["SNS_ALLOWED_TOPIC_ARNS"] || "").split(",").map(&:strip).reject(&:empty?)
  end
end
