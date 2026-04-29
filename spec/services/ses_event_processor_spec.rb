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
  end
end
