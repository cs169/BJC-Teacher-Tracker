# frozen_string_literal: true

# == Schema Information
#
# Table name: email_addresses
#
#  id                       :bigint           not null, primary key
#  bounced                  :boolean          default(FALSE), not null
#  email                    :string           not null
#  emails_delivered         :integer          default(0), not null
#  emails_sent              :integer          default(0), not null
#  last_delivery_event_at   :datetime
#  last_delivery_event_type :string
#  primary                  :boolean          default(FALSE), not null
#  suppressed_at            :datetime
#  suppression_reason       :string
#  suppression_source       :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  teacher_id               :bigint           not null
#
# Indexes
#
#  index_email_addresses_on_email                   (email) UNIQUE
#  index_email_addresses_on_last_delivery_event_at  (last_delivery_event_at)
#  index_email_addresses_on_suppressed_at           (suppressed_at)
#  index_email_addresses_on_teacher_id              (teacher_id)
#  index_email_addresses_on_teacher_id_and_primary  (teacher_id,primary) UNIQUE WHERE ("primary" = true)
#
# Foreign Keys
#
#  fk_rails_...  (teacher_id => teachers.id)
#
require "rails_helper"

RSpec.describe EmailAddress, type: :model do
  fixtures :all

  describe "delivery tracking" do
    let(:email) { email_addresses(:validated_teacher_email) }

    describe "#undelivered_count" do
      it "returns 0 when all emails are delivered" do
        email.update_columns(emails_sent: 10, emails_delivered: 10)
        expect(email.undelivered_count).to eq(0)
      end

      it "returns the difference between sent and delivered" do
        email.update_columns(emails_sent: 10, emails_delivered: 7)
        expect(email.undelivered_count).to eq(3)
      end

      it "never returns negative" do
        email.update_columns(emails_sent: 0, emails_delivered: 0)
        expect(email.undelivered_count).to eq(0)
      end
    end

    describe "#has_undelivered?" do
      it "returns false when no undelivered emails" do
        email.update_columns(emails_sent: 5, emails_delivered: 5)
        expect(email.has_undelivered?).to be false
      end

      it "returns true when there are undelivered emails" do
        email.update_columns(emails_sent: 10, emails_delivered: 7)
        expect(email.has_undelivered?).to be true
      end
    end

    describe "scopes" do
      describe ".bounced" do
        it "returns only bounced email addresses" do
          email.update_column(:bounced, true)
          expect(EmailAddress.bounced).to include(email)
        end

        it "excludes non-bounced email addresses" do
          expect(EmailAddress.bounced).not_to include(email)
        end
      end

      describe ".with_undelivered" do
        it "returns emails where sent > delivered" do
          email.update_columns(emails_sent: 10, emails_delivered: 7)
          expect(EmailAddress.with_undelivered).to include(email)
        end

        it "excludes emails where sent == delivered" do
          email.update_columns(emails_sent: 5, emails_delivered: 5)
          expect(EmailAddress.with_undelivered).not_to include(email)
        end
      end
    end

    describe "default values" do
      it "has 0 emails_sent by default" do
        expect(email.emails_sent).to eq(0)
      end

      it "has 0 emails_delivered by default" do
        expect(email.emails_delivered).to eq(0)
      end

      it "is not bounced by default" do
        expect(email.bounced?).to be false
      end
    end
  end

  describe "suppression and deliverability" do
    let(:email) { email_addresses(:validated_teacher_email) }

    describe "#suppressed?" do
      it "returns false when suppressed_at is nil" do
        expect(email.suppressed?).to be false
      end

      it "returns true when suppressed_at is set" do
        email.update_columns(suppressed_at: Time.current)
        expect(email.suppressed?).to be true
      end
    end

    describe "#deliverable?" do
      it "returns true when not suppressed" do
        expect(email.deliverable?).to be true
      end

      it "returns false when suppressed" do
        email.update_columns(suppressed_at: Time.current)
        expect(email.deliverable?).to be false
      end
    end

    describe ".suppressed scope" do
      it "includes suppressed emails" do
        email.update_columns(suppressed_at: Time.current)
        expect(EmailAddress.suppressed).to include(email)
      end

      it "excludes non-suppressed emails" do
        expect(EmailAddress.suppressed).not_to include(email)
      end
    end

    describe ".deliverable scope" do
      it "includes non-suppressed emails" do
        expect(EmailAddress.deliverable).to include(email)
      end

      it "excludes suppressed emails" do
        email.update_columns(suppressed_at: Time.current)
        expect(EmailAddress.deliverable).not_to include(email)
      end
    end

    describe ".with_deliverability_issues scope" do
      it "includes suppressed emails" do
        email.update_columns(suppressed_at: Time.current)
        expect(EmailAddress.with_deliverability_issues).to include(email)
      end

      it "includes emails with undelivered messages" do
        email.update_columns(emails_sent: 5, emails_delivered: 2)
        expect(EmailAddress.with_deliverability_issues).to include(email)
      end

      it "excludes healthy emails" do
        email.update_columns(emails_sent: 5, emails_delivered: 5, suppressed_at: nil)
        expect(EmailAddress.with_deliverability_issues).not_to include(email)
      end
    end

    describe "#recalculate_deliverability!" do
      it "calculates counters from delivery events" do
        EmailDeliveryEvent.create!(
          provider: "aws_ses", sns_message_id: "rc-1", ses_message_id: "ses-rc-1",
          recipient_email: email.email, event_type: "send",
          event_occurred_at: 2.hours.ago, email_address: email, message_tags: {}, payload: {}
        )
        EmailDeliveryEvent.create!(
          provider: "aws_ses", sns_message_id: "rc-2", ses_message_id: "ses-rc-1",
          recipient_email: email.email, event_type: "delivery",
          event_occurred_at: 1.hour.ago, email_address: email, message_tags: {}, payload: {}
        )

        email.recalculate_deliverability!
        email.reload

        expect(email.emails_sent).to eq(1) # 2 trackable events but same ses_message_id → 1 distinct
        expect(email.emails_delivered).to eq(1)
        expect(email.last_delivery_event_type).to eq("delivery")
        expect(email).not_to be_suppressed
      end

      it "marks as suppressed when a permanent bounce exists" do
        EmailDeliveryEvent.create!(
          provider: "aws_ses", sns_message_id: "rc-b1", ses_message_id: "ses-rc-b1",
          recipient_email: email.email, event_type: "bounce", bounce_type: "Permanent",
          event_occurred_at: 1.hour.ago, email_address: email, message_tags: {}, payload: {}
        )

        email.recalculate_deliverability!
        email.reload

        expect(email).to be_suppressed
        expect(email.suppression_reason).to eq("hard_bounce")
        expect(email.bounced?).to be(true)
      end

      it "marks as suppressed on complaint" do
        EmailDeliveryEvent.create!(
          provider: "aws_ses", sns_message_id: "rc-c1", ses_message_id: "ses-rc-c1",
          recipient_email: email.email, event_type: "complaint",
          event_occurred_at: 1.hour.ago, email_address: email, message_tags: {}, payload: {}
        )

        email.recalculate_deliverability!
        email.reload

        expect(email).to be_suppressed
        expect(email.suppression_reason).to eq("complaint")
      end

      it "handles no events gracefully" do
        email.recalculate_deliverability!
        email.reload

        expect(email.emails_sent).to eq(0)
        expect(email.emails_delivered).to eq(0)
        expect(email).not_to be_suppressed
        expect(email.last_delivery_event_type).to be_nil
      end
    end
  end
end
