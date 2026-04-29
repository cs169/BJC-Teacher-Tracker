# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::SesNotificationsController, type: :request do
  fixtures :all

  let(:topic_arn) { "arn:aws:sns:us-west-2:123456789012:ses-events" }
  let(:email) { email_addresses(:validated_teacher_email) }

  def ses_fixture(name)
    JSON.parse(File.read(Rails.root.join("spec/fixtures/files/ses/#{name}.json")))
  end

  def notification_envelope(fixture_name, message_id: "sns-msg-#{SecureRandom.hex(4)}")
    {
      "Type" => "Notification",
      "MessageId" => message_id,
      "TopicArn" => topic_arn,
      "Message" => ses_fixture(fixture_name).to_json,
      "Timestamp" => "2026-04-23T10:00:00.000Z",
      "SignatureVersion" => "1",
      "Signature" => "stubbed",
      "SigningCertURL" => "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-xxx.pem"
    }
  end

  def post_envelope(envelope)
    post ses_webhook_path, params: envelope.to_json, headers: { "Content-Type" => "application/json" }
  end

  before do
    allow(SnsMessageVerifier).to receive(:verify!) { |raw| JSON.parse(raw) }
  end

  describe "POST /webhooks/ses" do
    context "with a valid Delivery notification" do
      it "returns 204 No Content" do
        post_envelope(notification_envelope("delivery"))
        expect(response).to have_http_status(:no_content)
      end

      it "increments the matching email's emails_delivered" do
        expect {
          post_envelope(notification_envelope("delivery"))
        }.to change { email.reload.emails_delivered }.by(1)
      end

      it "creates a SesDeliveryEvent row" do
        expect {
          post_envelope(notification_envelope("delivery"))
        }.to change(SesDeliveryEvent, :count).by(1)
      end
    end

    context "with a valid Send notification" do
      it "increments emails_sent" do
        expect {
          post_envelope(notification_envelope("send"))
        }.to change { email.reload.emails_sent }.by(1)
      end
    end

    context "with a valid soft Bounce notification" do
      it "increments soft_bounce_count and does not set bounced" do
        post_envelope(notification_envelope("soft_bounce"))
        expect(email.reload.soft_bounce_count).to eq(1)
        expect(email.bounced?).to be false
      end
    end

    context "with a valid hard Bounce notification" do
      it "increments hard_bounce_count and sets bounced to true" do
        post_envelope(notification_envelope("hard_bounce"))
        expect(email.reload.hard_bounce_count).to eq(1)
        expect(email.bounced?).to be true
      end
    end

    context "with a valid Complaint notification" do
      it "increments hard_bounce_count and sets bounced to true" do
        post_envelope(notification_envelope("complaint"))
        expect(email.reload.hard_bounce_count).to eq(1)
        expect(email.bounced?).to be true
      end
    end

    context "when signature verification fails" do
      it "returns 401 and does not update counters" do
        allow(SnsMessageVerifier).to receive(:verify!)
          .and_raise(SnsMessageVerifier::VerificationError, "bad sig")

        expect {
          post_envelope(notification_envelope("delivery"))
        }.not_to change { email.reload.emails_delivered }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the same MessageId is delivered twice" do
      it "only increments the counter once" do
        envelope = notification_envelope("delivery", message_id: "sns-msg-dedupe-1")

        post_envelope(envelope)
        expect {
          post_envelope(envelope)
        }.not_to change { email.reload.emails_delivered }

        expect(email.reload.emails_delivered).to eq(1)
      end

      it "only creates one SesDeliveryEvent row" do
        envelope = notification_envelope("delivery", message_id: "sns-msg-dedupe-2")

        post_envelope(envelope)
        expect {
          post_envelope(envelope)
        }.not_to change(SesDeliveryEvent, :count)
      end
    end

    context "when the inner Message JSON is malformed" do
      it "returns 400" do
        envelope = notification_envelope("delivery")
        envelope["Message"] = "not json"
        post_envelope(envelope)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when the message is a SubscriptionConfirmation" do
      it "confirms the subscription and returns 204" do
        envelope = {
          "Type" => "SubscriptionConfirmation",
          "MessageId" => "sub-msg-1",
          "TopicArn" => topic_arn,
          "SubscribeURL" => "https://sns.us-west-2.amazonaws.com/?Action=ConfirmSubscription&Token=abc",
          "Timestamp" => "2026-04-23T10:00:00.000Z",
          "SignatureVersion" => "1",
          "Signature" => "stubbed",
          "SigningCertURL" => "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-xxx.pem"
        }

        expect(SnsSubscriptionConfirmer).to receive(:confirm!).with(envelope["SubscribeURL"])

        post_envelope(envelope)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when the message is an UnsubscribeConfirmation" do
      it "returns 204 and does not process anything" do
        envelope = {
          "Type" => "UnsubscribeConfirmation",
          "MessageId" => "unsub-msg-1",
          "TopicArn" => topic_arn,
          "Timestamp" => "2026-04-23T10:00:00.000Z",
          "SignatureVersion" => "1",
          "Signature" => "stubbed",
          "SigningCertURL" => "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-xxx.pem"
        }

        expect(SesEventProcessor).not_to receive(:new)
        expect(SnsSubscriptionConfirmer).not_to receive(:confirm!)

        post_envelope(envelope)
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when the recipient email is unknown" do
      it "returns 204 and still creates an event row" do
        expect {
          post_envelope(notification_envelope("unknown_recipient_delivery"))
        }.to change(SesDeliveryEvent, :count).by(1)
        expect(response).to have_http_status(:no_content)
        expect(SesDeliveryEvent.last.email_address_id).to be_nil
      end
    end
  end
end
