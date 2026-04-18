# frozen_string_literal: true

# == Schema Information
#
# Table name: teachers
#
#  id                    :integer          not null, primary key
#  admin                 :boolean          default(FALSE)
#  application_status    :string           default("not_reviewed")
#  education_level       :integer          default(NULL)
#  email                 :string
#  first_name            :string
#  ip_history            :inet             default([]), is an Array
#  languages             :string           default(["\"English\""]), is an Array
#  last_name             :string
#  last_session_at       :datetime
#  mailbluster_synced_at :datetime
#  more_info             :string
#  personal_email        :string
#  personal_website      :string
#  session_count         :integer          default(0)
#  snap                  :string
#  status                :integer
#  verification_notes    :text
#  created_at            :datetime
#  updated_at            :datetime
#  mailbluster_id        :integer
#  school_id             :integer
#
# Indexes
#
#  index_teachers_on_email                     (email) UNIQUE
#  index_teachers_on_email_and_first_name      (email,first_name)
#  index_teachers_on_email_and_personal_email  (email,personal_email) UNIQUE
#  index_teachers_on_mailbluster_id            (mailbluster_id) UNIQUE
#  index_teachers_on_school_id                 (school_id)
#  index_teachers_on_snap                      (snap) UNIQUE WHERE ((snap)::text <> ''::text)
#  index_teachers_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (school_id => schools.id)
#
require "rails_helper"

RSpec.describe Teacher, type: :model do
  fixtures :all

  let(:teacher) { teachers(:bob) }

  it "formats a proper email name" do
    expect(teacher.email_name).to eq "Bob Johnson <bob@gmail.com>"
  end

  it "formats a proper email name filtering commas" do
    teacher.update(last_name: "Johnson, III")
    expect(teacher.email_name).to eq "Bob Johnson III <bob@gmail.com>"
  end

  it "should be valid" do
    expect(teacher.valid?).to be true
  end

  it "requires personal_website" do
      new_teacher = Teacher.new(
        first_name: "Test",
        last_name: "User",
        status: "non_csp_teacher",
        personal_website: ""
      )
      expect(new_teacher).not_to be_valid
      expect(new_teacher.errors[:personal_website]).to include("can't be blank")
    end

  it "shows a text status" do
    expect(teacher.text_status).to eq "I am teaching BJC but not as an AP CS Principles course."
  end

  it "shows a short status" do
    expect(teacher.display_status).to eq "Non CSP Teacher"
  end

  it "shows an application status" do
    expect(teacher.display_application_status).to eq "Denied"
  end

  it "shows Unknown education level" do
    expect(teacher.display_education_level).to eq "?"
  end

  describe "teacher with info_needed application status" do
    let(:teacher) { teachers(:reimu) }

    it "does not change a info_need status to not_reviewed if submitted without changes" do
      expect do
        # Same primary email, which means no any change compared to last time
        teacher.email_addresses.find_by(email: "reimu@touhou.com").update(primary: true)
      end.not_to change(teacher, :application_status)
    end

    it "changes a info_needed status to not_reviewed" do
      expect do
        # Changes the status to not_reviewed only when there are meaningful changes
        teacher.email_addresses.find_by(email: "reimu@touhou.com").update(email: "reimu_different_email@touhou.com")
      end.to change(teacher, :application_status)
               .from("info_needed").to("not_reviewed")
    end

    it "can change a not_reviewed status to info_needed" do
      expect(teacher.more_info).to eq "Best Touhou Character"
      expect do
        teacher.update(more_info: "updated info")
      end.to change(teacher, :more_info)
               .from("Best Touhou Character").to("updated info")
    end
  end

  describe "teacher with more info" do
    let(:teacher) { teachers(:admin) }

    it "shows a short status with more info" do
      expect(teacher.more_info).to eq "A CS169 Student"
      expect(teacher.display_status).to eq "Other | A CS169 Student"
    end

    it "shows an application status" do
      expect(teacher.display_application_status).to eq "Validated"
    end
  end

  describe "teacher with not_reviewed application status" do
    let(:teacher) { teachers(:long) }

    it "shows an application status" do
      expect(teacher.display_application_status).to eq "Not Reviewed"
    end
  end

  describe ".search_non_admins" do
    it "finds teacher by first name" do
      expect(Teacher.search_non_admins("bob")).to include(teachers(:bob))
    end

    it "finds teacher by last name" do
      expect(Teacher.search_non_admins("hakurei")).to include(teachers(:reimu))
    end

    it "finds teacher by email" do
      expect(Teacher.search_non_admins("bob@gmail")).to include(teachers(:bob))
    end

    it "finds teacher by snap username" do
      # long fixture has snap: "song"
      expect(Teacher.search_non_admins("song")).to include(teachers(:long))
    end

    it "finds teachers by school name" do
      results = Teacher.search_non_admins("berkeley")
      expect(results).to include(teachers(:bob), teachers(:barney))
    end

    it "excludes admin teachers" do
      # "Wang" is admin's last name and unique to that fixture —
      # if admin is not excluded, this would return a result; it should be empty
      expect(Teacher.search_non_admins("Wang")).to be_empty
    end

    it "returns empty when nothing matches" do
      expect(Teacher.search_non_admins("zzznomatch999")).to be_empty
    end

    it "is case-insensitive" do
      expect(Teacher.search_non_admins("BOB")).to include(teachers(:bob))
    end
  end

  describe "MailBluster helper methods" do
    let(:validated_teacher) { teachers(:validated_teacher) }

    describe "#mailbluster_synced?" do
      it "returns false when mailbluster_id is nil" do
        expect(validated_teacher.mailbluster_synced?).to be false
      end

      it "returns true when mailbluster_id is present" do
        validated_teacher.update_column(:mailbluster_id, 12345)
        expect(validated_teacher.mailbluster_synced?).to be true
      end
    end

    describe "#mailbluster_profile_url" do
      it "returns nil when not synced" do
        expect(validated_teacher.mailbluster_profile_url).to be_nil
      end

      it "returns the MailBluster profile URL when synced" do
        validated_teacher.update_column(:mailbluster_id, 12345)
        expect(validated_teacher.mailbluster_profile_url).to eq("https://app.mailbluster.com/leads/12345")
      end
    end

    describe "#primary_email_sent" do
      it "returns 0 by default" do
        expect(validated_teacher.primary_email_sent).to eq(0)
      end

      it "returns the email sent count from primary email address" do
        email = validated_teacher.email_addresses.find_by(primary: true)
        email.update_column(:emails_sent, 10)
        expect(validated_teacher.primary_email_sent).to eq(10)
      end
    end

    describe "#primary_email_delivered" do
      it "returns 0 by default" do
        expect(validated_teacher.primary_email_delivered).to eq(0)
      end

      it "returns the email delivered count from primary email address" do
        email = validated_teacher.email_addresses.find_by(primary: true)
        email.update_column(:emails_delivered, 8)
        expect(validated_teacher.primary_email_delivered).to eq(8)
      end
    end

    describe "#primary_email_bounced" do
      it "returns 'No' by default" do
        expect(validated_teacher.primary_email_bounced).to eq("No")
      end

      it "returns 'Yes' when primary email is bounced" do
        email = validated_teacher.email_addresses.find_by(primary: true)
        email.update_column(:bounced, true)
        expect(validated_teacher.primary_email_bounced).to eq("Yes")
      end
    end
  end

  describe ".csv_export" do
    it "includes mailbluster_id column" do
      csv = Teacher.csv_export
      expect(csv).to include("mailbluster_id")
    end

    it "includes email delivery columns" do
      csv = Teacher.csv_export
      expect(csv).to include("primary_email_sent")
      expect(csv).to include("primary_email_delivered")
      expect(csv).to include("primary_email_bounced")
    end
  end

  describe "deliverability helpers" do
    let(:validated_teacher) { teachers(:validated_teacher) }

    it "returns true for marketing_subscribed? when the primary email is deliverable" do
      expect(validated_teacher.marketing_subscribed?).to be(true)
    end

    it "returns false for marketing_subscribed? when the primary email is suppressed" do
      validated_teacher.primary_email_address.update_columns(suppressed_at: Time.current, suppression_reason: "hard_bounce")

      expect(validated_teacher.marketing_subscribed?).to be(false)
    end

    it "finds teachers with deliverability issues" do
      validated_teacher.primary_email_address.update_columns(emails_sent: 2, emails_delivered: 0)

      expect(Teacher.with_deliverability_issues).to include(validated_teacher)
    end
  end
end
