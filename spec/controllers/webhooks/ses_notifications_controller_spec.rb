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
      "SigningCertURL" => "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-0123456789abcdef0123456789abcdef.pem"
    }
  end

  def post_envelope(envelope)
    post_raw(envelope.to_json)
  end

  def post_raw(body)
    post ses_webhook_path, params: body, headers: { "Content-Type" => "application/json" }
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
          "SigningCertURL" => "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-0123456789abcdef0123456789abcdef.pem"
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
          "SigningCertURL" => "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-0123456789abcdef0123456789abcdef.pem"
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

    context "with a notificationType (identity feedback) Bounce" do
      it "increments hard_bounce_count and sets bounced" do
        message = ses_fixture("hard_bounce").except("eventType").merge("notificationType" => "Bounce")
        envelope = notification_envelope("hard_bounce").merge("Message" => message.to_json)

        post_envelope(envelope)
        expect(response).to have_http_status(:no_content)
        expect(email.reload.hard_bounce_count).to eq(1)
        expect(email.bounced?).to be true
      end
    end

    context "when the verified inner Message is not a JSON object" do
      ["[1, 2]", "42", "\"hello\""].each do |message|
        it "ignores #{message} with 204 and changes nothing" do
          envelope = notification_envelope("delivery").merge("Message" => message)
          expect(SesEventProcessor).not_to receive(:new)

          expect { post_envelope(envelope) }.not_to change(SesDeliveryEvent, :count)
          expect(response).to have_http_status(:no_content)
        end
      end

      it "ignores a missing Message with 204" do
        post_envelope(notification_envelope("delivery").except("Message"))
        expect(response).to have_http_status(:no_content)
      end
    end

    context "when the inner SES event has the wrong shape" do
      it "returns 400 instead of raising" do
        message = { "eventType" => "Bounce", "bounce" => "oops" }
        post_envelope(notification_envelope("delivery").merge("Message" => message.to_json))
        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when confirming a subscription can't reach AWS" do
      it "returns 503 so SNS retries" do
        allow(SnsSubscriptionConfirmer).to receive(:confirm!)
          .and_raise(SnsSubscriptionConfirmer::NetworkError, "Net::OpenTimeout")
        post_envelope("Type" => "SubscriptionConfirmation", "TopicArn" => topic_arn,
                      "SubscribeURL" => "https://sns.us-west-2.amazonaws.com/?Token=x")
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context "with the real verifier (bad input from unauthenticated callers)" do
      before do
        SnsMessageVerifier.reset_aws_verifier!
        allow(SnsMessageVerifier).to receive(:verify!).and_call_original
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("SNS_ALLOWED_TOPIC_ARNS").and_return(topic_arn)
      end

      ["[]", "1", "null", "not json", ""].each do |body|
        it "returns 400 for body #{body.inspect}" do
          post_raw(body)
          expect(response).to have_http_status(:bad_request)
        end
      end

      it "returns 401 (not 500) for an allowlisted topic with no SigningCertURL" do
        post_envelope(notification_envelope("delivery").except("SigningCertURL"))
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 for a non-allowlisted topic" do
        post_envelope(notification_envelope("delivery").merge("TopicArn" => "arn:aws:sns:us-west-2:1:evil"))
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 413 for a body over 256 KB without verifying it" do
        expect(SnsMessageVerifier).not_to receive(:verify!)
        post_raw({ "Message" => "x" * (256.kilobytes + 1) }.to_json)
        expect(response).to have_http_status(:payload_too_large)
      end
    end
  end
end
