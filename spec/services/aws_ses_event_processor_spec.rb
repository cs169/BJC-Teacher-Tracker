# frozen_string_literal: true

require "rails_helper"

RSpec.describe AwsSesEventProcessor, type: :service do
  fixtures :all
  include ActiveJob::TestHelper

  let(:email_address) { email_addresses(:validated_teacher_email) }

  before do
    clear_enqueued_jobs
  end

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

    expect {
      described_class.new(sns_message_id: "bounce-1", topic_arn: "arn:aws:sns:test", ses_event: payload).call
    }.to have_enqueued_job(SyncTeacherToMailblusterJob).with(email_address.teacher_id)

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

  it "does NOT suppress on transient bounce events" do
    payload = build_event(
      event_type: "Bounce",
      sns_message_id: "bounce-transient",
      event_payload: {
        "bounce" => {
          "bounceType" => "Transient",
          "bounceSubType" => "General",
          "timestamp" => "2026-04-18T12:02:00.000Z",
          "bouncedRecipients" => [{ "emailAddress" => email_address.email }]
        }
      }
    )

    expect {
      described_class.new(sns_message_id: "bounce-transient", topic_arn: "arn:aws:sns:test", ses_event: payload).call
    }.not_to have_enqueued_job(SyncTeacherToMailblusterJob)

    email_address.reload
    expect(email_address).not_to be_suppressed
    expect(email_address.bounced?).to be(false)
    expect(email_address.emails_sent).to eq(1)
  end

  it "suppresses addresses on complaint events" do
    payload = build_event(
      event_type: "Complaint",
      sns_message_id: "complaint-1",
      event_payload: {
        "complaint" => {
          "complaintFeedbackType" => "abuse",
          "timestamp" => "2026-04-18T12:03:00.000Z",
          "complainedRecipients" => [{ "emailAddress" => email_address.email }]
        }
      }
    )

    expect {
      described_class.new(sns_message_id: "complaint-1", topic_arn: "arn:aws:sns:test", ses_event: payload).call
    }.to have_enqueued_job(SyncTeacherToMailblusterJob)

    email_address.reload
    expect(email_address).to be_suppressed
    expect(email_address.suppression_reason).to eq("complaint")
  end

  it "suppresses addresses on reject events" do
    payload = build_event(
      event_type: "Reject",
      sns_message_id: "reject-1",
      event_payload: {}
    )

    expect {
      described_class.new(sns_message_id: "reject-1", topic_arn: "arn:aws:sns:test", ses_event: payload).call
    }.to have_enqueued_job(SyncTeacherToMailblusterJob)

    email_address.reload
    expect(email_address).to be_suppressed
    expect(email_address.suppression_reason).to eq("provider_reject")
  end

  it "records send events without suppression" do
    payload = build_event(
      event_type: "Send",
      sns_message_id: "send-1",
      event_payload: {}
    )

    described_class.new(sns_message_id: "send-1", topic_arn: "arn:aws:sns:test", ses_event: payload).call

    email_address.reload
    expect(EmailDeliveryEvent.count).to eq(1)
    expect(email_address).not_to be_suppressed
  end

  it "handles events for unknown email addresses" do
    payload = build_event(
      event_type: "Delivery",
      sns_message_id: "delivery-unknown",
      mail_overrides: {
        "destination" => ["unknown@nowhere.com"],
        "tags" => {
          "app" => ["bjc_teacher_tracker"],
          "teacher_id" => [email_address.teacher_id.to_s]
        }
      },
      event_payload: {
        "delivery" => {
          "timestamp" => "2026-04-18T12:01:00.000Z",
          "recipients" => ["unknown@nowhere.com"]
        }
      }
    )

    expect(described_class.new(sns_message_id: "delivery-unknown", topic_arn: "arn:aws:sns:test", ses_event: payload).call).to eq(1)

    event = EmailDeliveryEvent.last
    expect(event.email_address).to be_nil
    expect(event.teacher).to eq(email_address.teacher)
    expect(event.recipient_email).to eq("unknown@nowhere.com")
  end

  it "does not enqueue MailBluster sync for non-primary email bounce" do
    secondary = EmailAddress.create!(teacher: email_address.teacher, email: "secondary@test.edu", primary: false)

    payload = {
      "eventType" => "Bounce",
      "mail" => {
        "messageId" => "ses-bounce-secondary",
        "timestamp" => "2026-04-18T12:00:00.000Z",
        "destination" => [secondary.email],
        "tags" => {
          "app" => ["bjc_teacher_tracker"],
          "teacher_id" => [secondary.teacher_id.to_s]
        }
      },
      "bounce" => {
        "bounceType" => "Permanent",
        "bounceSubType" => "General",
        "timestamp" => "2026-04-18T12:02:00.000Z",
        "bouncedRecipients" => [{ "emailAddress" => secondary.email }]
      }
    }

    expect {
      described_class.new(sns_message_id: "bounce-secondary", topic_arn: "arn:aws:sns:test", ses_event: payload).call
    }.not_to have_enqueued_job(SyncTeacherToMailblusterJob)

    secondary.reload
    expect(secondary).to be_suppressed
  end

  it "matches events by configuration set when app tag is absent" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("AWS_SES_CONFIGURATION_SET").and_return("bjc-ses-config")

    payload = build_event(
      event_type: "Delivery",
      sns_message_id: "delivery-configset",
      mail_overrides: {
        "tags" => {
          "ses:configuration-set" => ["bjc-ses-config"],
          "teacher_id" => [email_address.teacher_id.to_s]
        }
      },
      event_payload: {
        "delivery" => {
          "timestamp" => "2026-04-18T12:01:00.000Z",
          "recipients" => [email_address.email]
        }
      }
    )

    expect(described_class.new(sns_message_id: "delivery-configset", topic_arn: "arn:aws:sns:test", ses_event: payload).call).to eq(1)
  end

  it "handles multiple recipients in a single bounce event" do
    secondary = EmailAddress.create!(teacher: email_address.teacher, email: "secondary2@test.edu", primary: false)

    payload = {
      "eventType" => "Bounce",
      "mail" => {
        "messageId" => "ses-multi",
        "timestamp" => "2026-04-18T12:00:00.000Z",
        "destination" => [email_address.email, secondary.email],
        "tags" => {
          "app" => ["bjc_teacher_tracker"],
          "teacher_id" => [email_address.teacher_id.to_s]
        }
      },
      "bounce" => {
        "bounceType" => "Permanent",
        "bounceSubType" => "General",
        "timestamp" => "2026-04-18T12:02:00.000Z",
        "bouncedRecipients" => [
          { "emailAddress" => email_address.email },
          { "emailAddress" => secondary.email }
        ]
      }
    }

    result = described_class.new(sns_message_id: "bounce-multi", topic_arn: "arn:aws:sns:test", ses_event: payload).call
    expect(result).to eq(2)
    expect(EmailDeliveryEvent.count).to eq(2)
  end
end