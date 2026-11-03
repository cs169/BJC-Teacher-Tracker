# frozen_string_literal: true

require "rails_helper"

RSpec.describe SesEventProcessor, type: :service do
  fixtures :all

  let(:email) { email_addresses(:validated_teacher_email) }
  let(:bob_email) { email_addresses(:bob_email) }

  def load_event(name)
    JSON.parse(File.read(Rails.root.join("spec/fixtures/files/ses/#{name}.json")))
  end

  def process(name, sns_message_id: "sns-#{name}-#{SecureRandom.hex(4)}")
    described_class.new(load_event(name), sns_message_id:).call
  end

  describe "#call" do
    context "Send event" do
      it "increments emails_sent on the matching email address" do
        expect { process("send") }.to change { email.reload.emails_sent }.by(1)
      end

      it "does not change emails_delivered, soft_bounce_count, or hard_bounce_count" do
        process("send")
        email.reload
        expect(email.emails_delivered).to eq(0)
        expect(email.soft_bounce_count).to eq(0)
        expect(email.hard_bounce_count).to eq(0)
      end

      it "does not flip bounced" do
        process("send")
        expect(email.reload.bounced?).to be false
      end

      it "persists a SesDeliveryEvent row" do
        expect { process("send") }.to change(SesDeliveryEvent, :count).by(1)
      end

      it "updates last_ses_event_at" do
        expect { process("send") }.to change { email.reload.last_ses_event_at }.from(nil)
      end
    end

    context "Delivery event" do
      it "increments emails_delivered" do
        expect { process("delivery") }.to change { email.reload.emails_delivered }.by(1)
      end

      it "counts only delivery.recipients, not every address in mail.destination" do
        event = load_event("multi_recipient_delivery")
        event["delivery"]["recipients"] = ["validated@teacher.edu"]
        described_class.new(event, sns_message_id: "sns-partial").call
        expect(email.reload.emails_delivered).to eq(1)
        expect(bob_email.reload.emails_delivered).to eq(0)
      end

      it "records nothing when delivery.recipients is missing" do
        event = load_event("delivery")
        event["delivery"].delete("recipients")
        expect { described_class.new(event, sns_message_id: "sns-norecip").call }
          .not_to change(SesDeliveryEvent, :count)
      end
    end

    context "Bounce event with bounceType = Transient (soft bounce)" do
      it "increments soft_bounce_count" do
        expect { process("soft_bounce") }.to change { email.reload.soft_bounce_count }.by(1)
      end

      it "does NOT increment hard_bounce_count" do
        process("soft_bounce")
        expect(email.reload.hard_bounce_count).to eq(0)
      end

      it "does NOT set bounced to true" do
        process("soft_bounce")
        expect(email.reload.bounced?).to be false
      end
    end

    context "Bounce event with bounceType = Permanent (hard bounce)" do
      it "increments hard_bounce_count" do
        expect { process("hard_bounce") }.to change { email.reload.hard_bounce_count }.by(1)
      end

      it "does NOT increment soft_bounce_count" do
        process("hard_bounce")
        expect(email.reload.soft_bounce_count).to eq(0)
      end

      it "sets bounced to true" do
        process("hard_bounce")
        expect(email.reload.bounced?).to be true
      end
    end

    context "Complaint event" do
      it "increments hard_bounce_count (treated as hard bounce)" do
        expect { process("complaint") }.to change { email.reload.hard_bounce_count }.by(1)
      end

      it "sets bounced to true" do
        process("complaint")
        expect(email.reload.bounced?).to be true
      end
    end

    context "other event types (e.g. Reject)" do
      it "does not change any counter" do
        process("reject")
        email.reload
        expect(email.emails_sent).to eq(0)
        expect(email.emails_delivered).to eq(0)
        expect(email.soft_bounce_count).to eq(0)
        expect(email.hard_bounce_count).to eq(0)
      end

      it "does not persist a SesDeliveryEvent row" do
        expect { process("reject") }.not_to change(SesDeliveryEvent, :count)
      end
    end

    context "unknown recipient (no matching EmailAddress)" do
      it "does not raise" do
        expect { process("unknown_recipient_delivery") }.not_to raise_error
      end

      it "persists the event with email_address_id: nil" do
        expect { process("unknown_recipient_delivery") }.to change(SesDeliveryEvent, :count).by(1)
        event = SesDeliveryEvent.last
        expect(event.email_address_id).to be_nil
        expect(event.recipient_email).to eq("stranger@nowhere.example")
      end
    end

    context "multi-recipient event" do
      it "updates each recipient's counter" do
        process("multi_recipient_delivery")
        expect(email.reload.emails_delivered).to eq(1)
        expect(bob_email.reload.emails_delivered).to eq(1)
      end

      it "creates one event row per recipient" do
        expect { process("multi_recipient_delivery") }.to change(SesDeliveryEvent, :count).by(2)
      end
    end

    context "idempotency — duplicate SNS MessageId" do
      it "does not double-increment counters when the same event is processed twice" do
        process("delivery", sns_message_id: "sns-dup-delivery")
        expect { process("delivery", sns_message_id: "sns-dup-delivery") }
          .not_to change { email.reload.emails_delivered }
        expect(email.reload.emails_delivered).to eq(1)
      end

      it "does not create a duplicate SesDeliveryEvent row" do
        process("delivery", sns_message_id: "sns-dup-delivery-2")
        expect { process("delivery", sns_message_id: "sns-dup-delivery-2") }
          .not_to change(SesDeliveryEvent, :count)
      end
    end

    context "identity feedback notifications (notificationType instead of eventType)" do
      def as_feedback(name)
        event = load_event(name)
        event.merge("notificationType" => event.delete("eventType"))
      end

      def process_feedback(name)
        described_class.new(as_feedback(name), sns_message_id: "sns-fb-#{SecureRandom.hex(4)}").call
      end

      it "counts a Delivery" do
        expect { process_feedback("delivery") }.to change { email.reload.emails_delivered }.by(1)
      end

      it "counts a permanent Bounce and sets bounced" do
        process_feedback("hard_bounce")
        expect(email.reload.hard_bounce_count).to eq(1)
        expect(email.bounced?).to be true
      end

      it "counts a Complaint" do
        expect { process_feedback("complaint") }.to change { email.reload.hard_bounce_count }.by(1)
      end

      it "stores the event type on the event row" do
        process_feedback("soft_bounce")
        expect(SesDeliveryEvent.last.event_type).to eq("Bounce")
      end

      it "ignores the AmazonSnsSubscriptionSucceeded notice" do
        event = { "notificationType" => "AmazonSnsSubscriptionSucceeded", "message" => "ok" }
        expect { described_class.new(event, sns_message_id: "sns-ok").call }
          .not_to change(SesDeliveryEvent, :count)
      end
    end

    context "counter updates" do
      it "increments in SQL, so a stale in-memory record can't drop an increment" do
        stale = EmailAddress.find(email.id)
        EmailAddress.where(id: email.id).update_all(emails_delivered: 5)
        allow(EmailAddress).to receive(:find_by).and_return(stale)

        process("delivery")
        expect(email.reload.emails_delivered).to eq(6)
      end

      it "rolls back the event row if the counter update fails" do
        relation = instance_double(ActiveRecord::Relation)
        allow(EmailAddress).to receive(:where).and_return(relation)
        allow(relation).to receive(:update_all).and_raise(ActiveRecord::StatementInvalid, "boom")

        expect { process("delivery") }.to raise_error(ActiveRecord::StatementInvalid)
        expect(SesDeliveryEvent.count).to eq(0)
      end
    end

    context "malformed SES events" do
      it "raises ProcessingError for a non-Hash event" do
        expect { described_class.new([1], sns_message_id: "x").call }
          .to raise_error(SesEventProcessor::ProcessingError)
      end

      it "raises ProcessingError when a nested field has the wrong type" do
        event = { "eventType" => "Bounce", "bounce" => "oops" }
        expect { described_class.new(event, sns_message_id: "x").call }
          .to raise_error(SesEventProcessor::ProcessingError)
      end

      it "skips non-object recipient entries" do
        event = load_event("hard_bounce")
        event["bounce"]["bouncedRecipients"] = ["validated@teacher.edu", { "emailAddress" => "validated@teacher.edu" }]
        expect { described_class.new(event, sns_message_id: "x").call }.to change(SesDeliveryEvent, :count).by(1)
      end
    end
  end
end
