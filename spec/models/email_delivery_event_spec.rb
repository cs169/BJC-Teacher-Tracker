# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailDeliveryEvent, type: :model do
  fixtures :all

  let(:email_address) { email_addresses(:validated_teacher_email) }

  def build_event(overrides = {})
    EmailDeliveryEvent.new({
      provider: "aws_ses",
      sns_message_id: "sns-#{SecureRandom.hex(8)}",
      recipient_email: email_address.email,
      event_type: "delivery",
      event_occurred_at: Time.current,
      email_address: email_address,
      teacher: email_address.teacher,
      message_tags: {},
      payload: {}
    }.merge(overrides))
  end

  describe "validations" do
    it "is valid with all required attributes" do
      expect(build_event).to be_valid
    end

    %i[sns_message_id event_type recipient_email event_occurred_at].each do |field|
      it "requires #{field}" do
        event = build_event(field => nil)
        expect(event).not_to be_valid
        expect(event.errors[field]).to be_present
      end
    end

    it "enforces uniqueness on provider + sns_message_id + recipient_email" do
      build_event(sns_message_id: "dup-1").save!
      dup = build_event(sns_message_id: "dup-1")
      expect(dup).not_to be_valid
      expect(dup.errors[:sns_message_id]).to be_present
    end

    it "allows same sns_message_id with different recipient" do
      build_event(sns_message_id: "shared-1", recipient_email: email_address.email).save!
      other = build_event(sns_message_id: "shared-1", recipient_email: "other@example.com")
      other.email_address = nil
      expect(other).to be_valid
    end
  end

  describe "normalize_fields callback" do
    it "downcases event_type" do
      event = build_event(event_type: "DELIVERY")
      event.valid?
      expect(event.event_type).to eq("delivery")
    end

    it "strips and downcases recipient_email" do
      event = build_event(recipient_email: " FOO@Example.COM ")
      event.valid?
      expect(event.recipient_email).to eq("foo@example.com")
    end

    it "defaults provider to aws_ses when blank" do
      event = build_event(provider: "")
      event.valid?
      expect(event.provider).to eq("aws_ses")
    end

    it "defaults message_tags and payload to empty hashes" do
      event = build_event(message_tags: nil, payload: nil)
      event.valid?
      expect(event.message_tags).to eq({})
      expect(event.payload).to eq({})
    end
  end

  describe "scopes" do
    before do
      build_event(sns_message_id: "s1", event_type: "delivery", event_occurred_at: 2.hours.ago).save!
      build_event(sns_message_id: "s2", event_type: "bounce", bounce_type: "Permanent", event_occurred_at: 1.hour.ago).save!
      build_event(sns_message_id: "s3", event_type: "complaint", event_occurred_at: 30.minutes.ago).save!
      build_event(sns_message_id: "s4", event_type: "reject", event_occurred_at: 15.minutes.ago).save!
      build_event(sns_message_id: "s5", event_type: "send", event_occurred_at: 3.hours.ago).save!
    end

    it ".ordered returns events in chronological order" do
      types = described_class.ordered.pluck(:event_type)
      expect(types).to eq(%w[send delivery bounce complaint reject])
    end

    it ".trackable includes all trackable types" do
      expect(described_class.trackable.count).to eq(5)
    end

    it ".deliveries returns only delivery events" do
      expect(described_class.deliveries.pluck(:event_type).uniq).to eq(["delivery"])
    end

    it ".complaints returns only complaint events" do
      expect(described_class.complaints.pluck(:event_type).uniq).to eq(["complaint"])
    end

    it ".rejects returns only reject events" do
      expect(described_class.rejects.pluck(:event_type).uniq).to eq(["reject"])
    end

    it ".permanent_bounces returns only permanent bounce events" do
      events = described_class.permanent_bounces
      expect(events.count).to eq(1)
      expect(events.first.bounce_type).to eq("Permanent")
    end

    it ".suppressing includes complaints, rejects, and permanent bounces" do
      expect(described_class.suppressing.count).to eq(3)
    end
  end

  describe "predicate methods" do
    it "#send? is true for send events" do
      expect(build_event(event_type: "send").send?).to be(true)
      expect(build_event(event_type: "delivery").send?).to be(false)
    end

    it "#delivery? is true for delivery events" do
      expect(build_event(event_type: "delivery").delivery?).to be(true)
      expect(build_event(event_type: "bounce").delivery?).to be(false)
    end

    it "#bounce? is true for bounce events" do
      expect(build_event(event_type: "bounce").bounce?).to be(true)
      expect(build_event(event_type: "delivery").bounce?).to be(false)
    end

    it "#complaint? is true for complaint events" do
      expect(build_event(event_type: "complaint").complaint?).to be(true)
      expect(build_event(event_type: "bounce").complaint?).to be(false)
    end

    it "#reject? is true for reject events" do
      expect(build_event(event_type: "reject").reject?).to be(true)
      expect(build_event(event_type: "delivery").reject?).to be(false)
    end

    it "#permanent_bounce? is true only for permanent bounces" do
      expect(build_event(event_type: "bounce", bounce_type: "Permanent").permanent_bounce?).to be(true)
      expect(build_event(event_type: "bounce", bounce_type: "Transient").permanent_bounce?).to be(false)
      expect(build_event(event_type: "delivery").permanent_bounce?).to be(false)
    end

    it "#suppresses_address? for complaints, rejects, and permanent bounces" do
      expect(build_event(event_type: "complaint").suppresses_address?).to be(true)
      expect(build_event(event_type: "reject").suppresses_address?).to be(true)
      expect(build_event(event_type: "bounce", bounce_type: "Permanent").suppresses_address?).to be(true)
      expect(build_event(event_type: "bounce", bounce_type: "Transient").suppresses_address?).to be(false)
      expect(build_event(event_type: "delivery").suppresses_address?).to be(false)
    end
  end

  describe "#message_reference" do
    it "returns ses_message_id when present" do
      event = build_event(ses_message_id: "ses-123")
      expect(event.message_reference).to eq("ses-123")
    end

    it "falls back to sns: prefixed id" do
      event = build_event(ses_message_id: nil, sns_message_id: "sns-456")
      expect(event.message_reference).to eq("sns:sns-456")
    end
  end

  describe "associations" do
    it "belongs_to email_address optionally" do
      event = build_event(email_address: nil)
      expect(event).to be_valid
    end

    it "belongs_to teacher optionally" do
      event = build_event(teacher: nil)
      expect(event).to be_valid
    end
  end
end
