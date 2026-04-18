# frozen_string_literal: true

require "rails_helper"

RSpec.describe "AwsSnsNotifications", type: :request do
  let(:raw_body) { { Type: "Notification", MessageId: "sns-1", TopicArn: "arn:aws:sns:test", Message: "{}" }.to_json }
  let(:headers) { { "CONTENT_TYPE" => "application/json" } }

  it "accepts verified notifications" do
    envelope = JSON.parse(raw_body)
    allow(AwsSnsMessageVerifier).to receive(:verify!).with(raw_body).and_return(envelope)
    handler = instance_double(AwsSnsNotificationHandler, call: true)
    allow(AwsSnsNotificationHandler).to receive(:new).with(envelope).and_return(handler)

    post "/webhooks/aws/sns", params: raw_body, headers: headers

    expect(response).to have_http_status(:no_content)
  end

  it "rejects unverified notifications" do
    allow(AwsSnsMessageVerifier).to receive(:verify!).and_raise(AwsSnsMessageVerifier::VerificationError, "bad signature")

    post "/webhooks/aws/sns", params: raw_body, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns bad request for malformed notifications" do
    envelope = JSON.parse(raw_body)
    allow(AwsSnsMessageVerifier).to receive(:verify!).with(raw_body).and_return(envelope)
    allow(AwsSnsNotificationHandler).to receive(:new).and_raise(AwsSnsNotificationHandler::ProcessingError, "bad payload")

    post "/webhooks/aws/sns", params: raw_body, headers: headers

    expect(response).to have_http_status(:bad_request)
  end
end