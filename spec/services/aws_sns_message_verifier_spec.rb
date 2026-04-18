# frozen_string_literal: true

require "rails_helper"

RSpec.describe AwsSnsMessageVerifier, type: :service do
  let(:raw_body) do
    {
      Type: "Notification",
      MessageId: "sns-1",
      TopicArn: "arn:aws:sns:us-west-2:123456789012:teacher-mail-events",
      Message: "{}"
    }.to_json
  end

  before do
    allow_any_instance_of(Aws::SNS::MessageVerifier).to receive(:authenticate!).and_return(true)
  end

  it "returns the parsed SNS envelope when verification succeeds" do
    envelope = described_class.verify!(raw_body)

    expect(envelope["MessageId"]).to eq("sns-1")
  end

  it "rejects notifications from topics outside the allowlist" do
    original_topics = ENV["AWS_SNS_TOPIC_ARNS"]
    ENV["AWS_SNS_TOPIC_ARNS"] = "arn:aws:sns:us-west-2:123456789012:other-topic"

    expect {
      described_class.verify!(raw_body)
    }.to raise_error(AwsSnsMessageVerifier::VerificationError, "Unexpected SNS topic")
  ensure
    ENV["AWS_SNS_TOPIC_ARNS"] = original_topics
  end
end