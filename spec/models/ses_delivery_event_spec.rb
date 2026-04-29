# frozen_string_literal: true

require "rails_helper"

RSpec.describe SesDeliveryEvent, type: :model do
  fixtures :all

  let(:email) { email_addresses(:validated_teacher_email) }

  def build_event(overrides = {})
    SesDeliveryEvent.new({
      email_address: email,
      sns_message_id: "sns-#{SecureRandom.hex(4)}",
      event_type: "Delivery",
      recipient_email: email.email,
      event_occurred_at: Time.current,
      payload: { any: "json" }
    }.merge(overrides))
  end

  describe "validations" do
    it "is valid with all required attributes" do
      expect(build_event).to be_valid
    end

    it "requires sns_message_id" do
      event = build_event(sns_message_id: nil)
      expect(event).not_to be_valid
      expect(event.errors[:sns_message_id]).to be_present
    end

    it "requires event_type" do
      event = build_event(event_type: nil)
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to be_present
    end

    it "requires recipient_email" do
      event = build_event(recipient_email: nil)
      expect(event).not_to be_valid
      expect(event.errors[:recipient_email]).to be_present
    end

    it "requires event_occurred_at" do
      event = build_event(event_occurred_at: nil)
      expect(event).not_to be_valid
      expect(event.errors[:event_occurred_at]).to be_present
    end

    it "allows nil email_address (unknown recipient)" do
      event = build_event(email_address: nil)
      expect(event).to be_valid
    end
  end

  describe "uniqueness on (sns_message_id, recipient_email)" do
    it "rejects a duplicate row at the DB level" do
      attrs = {
        sns_message_id: "sns-dup-1",
        recipient_email: email.email,
        event_type: "Delivery",
        event_occurred_at: Time.current
      }
      SesDeliveryEvent.create!(attrs.merge(email_address: email))

      expect {
        SesDeliveryEvent.create!(attrs.merge(email_address: email))
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same sns_message_id for different recipients" do
      SesDeliveryEvent.create!(
        email_address: email,
        sns_message_id: "sns-multi",
        event_type: "Delivery",
        recipient_email: email.email,
        event_occurred_at: Time.current
      )

      other = email_addresses(:bob_email)
      expect {
        SesDeliveryEvent.create!(
          email_address: other,
          sns_message_id: "sns-multi",
          event_type: "Delivery",
          recipient_email: other.email,
          event_occurred_at: Time.current
        )
      }.not_to raise_error
    end
  end

  describe "payload" do
    it "defaults to an empty hash" do
      event = SesDeliveryEvent.create!(
        email_address: email,
        sns_message_id: "sns-payload",
        event_type: "Send",
        recipient_email: email.email,
        event_occurred_at: Time.current
      )
      expect(event.reload.payload).to eq({})
    end

    it "persists arbitrary JSON content" do
      event = SesDeliveryEvent.create!(
        email_address: email,
        sns_message_id: "sns-payload-2",
        event_type: "Bounce",
        bounce_type: "Permanent",
        recipient_email: email.email,
        event_occurred_at: Time.current,
        payload: { "bounce" => { "bounceType" => "Permanent" } }
      )
      expect(event.reload.payload).to eq("bounce" => { "bounceType" => "Permanent" })
    end
  end
end
