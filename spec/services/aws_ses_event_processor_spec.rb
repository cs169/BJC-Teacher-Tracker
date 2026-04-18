# frozen_string_literal: true

require "rails_helper"

RSpec.describe AwsSesEventProcessor, type: :service do
  fixtures :all

  let(:email_address) { email_addresses(:validated_teacher_email) }

  def build_event(event_type:, sns_message_id:, mail_overrides: {}, event_payload: {})
    {
      "eventType" => event_type,
      "mail" => {
        "messageId" => "ses-#{sns_message_id}",
        "timestamp" => "2026-04-18T12:00:00.000Z",
        "destination" => [email_address.email],
        "tags" => {
          "app" => ["bjc_teacher_tracker"],
          "teacher_id" => [email_address.teacher_id.to_s],
          "mailer_action" => ["welcome_email"]
        }
      }.merge(mail_overrides)
    }.merge(event_payload)
  end

  it "creates a delivery event and updates summary counters" do
    payload = build_event(
      event_type: "Delivery",
      sns_message_id: "delivery-1",
      event_payload: {
        "delivery" => {
          "timestamp" => "2026-04-18T12:01:00.000Z",
          "recipients" => [email_address.email]
        }
      }
    )

    described_class.new(sns_message_id: "delivery-1", topic_arn: "arn:aws:sns:test", ses_event: payload).call

    email_address.reload
    expect(EmailDeliveryEvent.count).to eq(1)
    expect(email_address.emails_sent).to eq(1)
    expect(email_address.emails_delivered).to eq(1)
    expect(email_address).not_to be_suppressed
    expect(email_address.last_delivery_event_type).to eq("delivery")
  end

  it "suppresses addresses on permanent bounce events" do
    payload = build_event(
      event_type: "Bounce",
      sns_message_id: "bounce-1",
      event_payload: {
        "bounce" => {
          "bounceType" => "Permanent",
          "bounceSubType" => "General",
          "timestamp" => "2026-04-18T12:02:00.000Z",
          "bouncedRecipients" => [{ "emailAddress" => email_address.email }]
        }
      }
    )

    described_class.new(sns_message_id: "bounce-1", topic_arn: "arn:aws:sns:test", ses_event: payload).call

    email_address.reload
    expect(email_address).to be_suppressed
    expect(email_address.bounced?).to be(true)
    expect(email_address.suppression_reason).to eq("hard_bounce")
    expect(email_address.emails_sent).to eq(1)
    expect(email_address.emails_delivered).to eq(0)
  end

  it "is idempotent for duplicate SNS notifications" do
    payload = build_event(
      event_type: "Delivery",
      sns_message_id: "delivery-duplicate",
      event_payload: {
        "delivery" => {
          "timestamp" => "2026-04-18T12:01:00.000Z",
          "recipients" => [email_address.email]
        }
      }
    )

    processor = described_class.new(sns_message_id: "delivery-duplicate", topic_arn: "arn:aws:sns:test", ses_event: payload)

    expect(processor.call).to eq(1)
    expect(processor.call).to eq(0)

    email_address.reload
    expect(EmailDeliveryEvent.count).to eq(1)
    expect(email_address.emails_sent).to eq(1)
    expect(email_address.emails_delivered).to eq(1)
  end

  it "ignores notifications that do not belong to this app" do
    payload = build_event(
      event_type: "Delivery",
      sns_message_id: "delivery-ignored",
      mail_overrides: { "tags" => { "app" => ["another_app"] } },
      event_payload: {
        "delivery" => {
          "timestamp" => "2026-04-18T12:01:00.000Z",
          "recipients" => [email_address.email]
        }
      }
    )

    expect(described_class.new(sns_message_id: "delivery-ignored", topic_arn: "arn:aws:sns:test", ses_event: payload).call).to eq(0)
    expect(EmailDeliveryEvent.count).to eq(0)
  end
end