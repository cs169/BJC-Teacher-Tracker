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
        .to raise_error(SnsMessageVerifier::VerificationError, /invalid json/i)
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
end
