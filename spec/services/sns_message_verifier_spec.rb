# frozen_string_literal: true

require "rails_helper"

RSpec.describe SnsMessageVerifier, type: :service do
  let(:topic_arn) { "arn:aws:sns:us-west-2:123456789012:ses-events" }
  let(:other_topic_arn) { "arn:aws:sns:us-west-2:123456789012:other-topic" }

  let(:envelope) do
    {
      "Type" => "Notification",
      "MessageId" => "abc-123",
      "TopicArn" => topic_arn,
      "Message" => '{"eventType":"Delivery"}',
      "Timestamp" => "2026-04-23T10:00:00.000Z",
      "SignatureVersion" => "1",
      "Signature" => "placeholder",
      "SigningCertURL" => "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-xxx.pem"
    }
  end

  let(:raw_body) { envelope.to_json }
  let(:verifier_double) { instance_double(Aws::SNS::MessageVerifier) }

  before do
    described_class.reset_aws_verifier!
    allow(Aws::SNS::MessageVerifier).to receive(:new).and_return(verifier_double)
    allow(verifier_double).to receive(:authenticate!).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SNS_ALLOWED_TOPIC_ARNS").and_return(topic_arn)
  end

  describe ".verify!" do
    it "returns the parsed envelope when signature is valid and topic is allowlisted" do
      expect(described_class.verify!(raw_body)).to eq(envelope)
    end

    it "raises VerificationError when the body is not valid JSON" do
      expect { described_class.verify!("not json") }
        .to raise_error(SnsMessageVerifier::MalformedEnvelopeError, /invalid json/i)
    end

    ["[]", "1", "\"string\"", "null", ""].each do |body|
      it "raises MalformedEnvelopeError for a non-object body #{body.inspect}" do
        expect { described_class.verify!(body) }
          .to raise_error(SnsMessageVerifier::MalformedEnvelopeError)
      end
    end

    it "wraps unexpected SDK errors (e.g. missing SigningCertURL) as VerificationError" do
      allow(verifier_double).to receive(:authenticate!).and_raise(URI::InvalidURIError, "bad URI(is not URI?): nil")

      expect { described_class.verify!(raw_body) }
        .to raise_error(SnsMessageVerifier::VerificationError, /InvalidURIError/)
    end

    it "reuses a single SDK verifier (and its cert cache) across calls" do
      3.times { described_class.verify!(raw_body) }
      expect(Aws::SNS::MessageVerifier).to have_received(:new).once
    end

    it "raises VerificationError when the signature is invalid" do
      allow(verifier_double).to receive(:authenticate!)
        .and_raise(Aws::SNS::MessageVerifier::VerificationError.new("bad sig"))

      expect { described_class.verify!(raw_body) }
        .to raise_error(SnsMessageVerifier::VerificationError, /signature/i)
    end

    it "raises VerificationError when TopicArn is not in the allowlist" do
      envelope["TopicArn"] = other_topic_arn
      expect { described_class.verify!(envelope.to_json) }
        .to raise_error(SnsMessageVerifier::VerificationError, /topic/i)
    end

    it "supports a comma-separated allowlist" do
      allow(ENV).to receive(:[]).with("SNS_ALLOWED_TOPIC_ARNS")
        .and_return("#{other_topic_arn},#{topic_arn}")

      expect(described_class.verify!(raw_body)).to eq(envelope)
    end

    it "trims whitespace in the allowlist entries" do
      allow(ENV).to receive(:[]).with("SNS_ALLOWED_TOPIC_ARNS")
        .and_return(" #{topic_arn} , #{other_topic_arn} ")

      expect(described_class.verify!(raw_body)).to eq(envelope)
    end

    it "raises VerificationError when the allowlist is empty" do
      allow(ENV).to receive(:[]).with("SNS_ALLOWED_TOPIC_ARNS").and_return("")
      expect { described_class.verify!(raw_body) }
        .to raise_error(SnsMessageVerifier::VerificationError, /topic/i)
    end
  end

  # End-to-end through the real AWS SDK verifier with a locally generated
  # certificate. Only the PEM download is stubbed.
  describe "with real signatures" do
    let(:key) { OpenSSL::PKey::RSA.new(2048) }
    let(:cert) do
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = cert.issuer = OpenSSL::X509::Name.parse("/CN=sns.us-west-2.amazonaws.com")
      cert.public_key = key.public_key
      cert.not_before = 1.hour.ago
      cert.not_after = 1.hour.from_now
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      cert
    end

    def sign(message)
      canonical = Aws::SNS::MessageVerifier::SIGNABLE_KEYS.filter_map do |k|
        "#{k}\n#{message[k]}\n" if message[k].present?
      end.join
      message.merge(
        "SignatureVersion" => "2",
        "Signature" => Base64.strict_encode64(key.sign(OpenSSL::Digest.new("SHA256"), canonical))
      )
    end

    let(:signed) { sign(envelope.except("Signature", "SignatureVersion")) }

    before do
      allow(Aws::SNS::MessageVerifier).to receive(:new).and_call_original
      allow_any_instance_of(Aws::SNS::MessageVerifier).to receive(:https_get).and_return(cert.to_pem) # rubocop:disable RSpec/AnyInstance
    end

    it "accepts a correctly signed message" do
      expect(described_class.verify!(signed.to_json)).to eq(signed)
    end

    it "rejects a message whose Message was tampered with" do
      tampered = signed.merge("Message" => '{"eventType":"Bounce"}')
      expect { described_class.verify!(tampered.to_json) }
        .to raise_error(SnsMessageVerifier::VerificationError, /signature/i)
    end

    it "rejects a message whose TopicArn was swapped for another allowlisted topic" do
      allow(ENV).to receive(:[]).with("SNS_ALLOWED_TOPIC_ARNS").and_return("#{topic_arn},#{other_topic_arn}")
      tampered = signed.merge("TopicArn" => other_topic_arn)
      expect { described_class.verify!(tampered.to_json) }
        .to raise_error(SnsMessageVerifier::VerificationError, /signature/i)
    end

    it "rejects a message with no SigningCertURL as unverified" do
      expect { described_class.verify!(signed.except("SigningCertURL").to_json) }
        .to raise_error(SnsMessageVerifier::VerificationError)
    end
  end
end
