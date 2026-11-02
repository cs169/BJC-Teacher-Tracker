# frozen_string_literal: true

require "rails_helper"

RSpec.describe MergeController, type: :request do
  fixtures :all

  let(:admin_teacher) { teachers(:admin) }
  let(:from_school) { schools(:berkeley) }
  let(:into_school) { schools(:stanfurd) }

  context "for a non-admin" do
    it "redirects preview to root" do
      get preview_school_merge_path(from: from_school.id, into: into_school.id)
      expect(response).to redirect_to(login_path)
    end

    it "redirects execute to root" do
      patch school_merge_path(from: from_school.id, into: into_school.id)
      expect(response).to redirect_to(login_path)
    end
  end

  describe "teacher merge" do
    let(:from_teacher) { teachers(:long) }
    let(:into_teacher) { teachers(:reimu) }

    before do
      log_in(admin_teacher)
    end

    it "moves the merged-from teacher's email addresses onto the surviving teacher" do
      from_email = from_teacher.primary_email
      into_email = into_teacher.primary_email

      patch merge_path(from: from_teacher.id, into: into_teacher.id)

      expect(Teacher.exists?(from_teacher.id)).to be false
      expect(into_teacher.reload.email_addresses.pluck(:email)).to match_array([from_email, into_email])
    end

    it "destroys exactly one teacher and creates none" do
      expect { patch merge_path(from: from_teacher.id, into: into_teacher.id) }
        .to change { Teacher.count }.by(-1)
    end

    it "skips email addresses the surviving teacher already has (case-insensitively)" do
      # A case-variant duplicate can only exist in legacy data, since
      # normalize_email downcases on save — bypass callbacks to create one.
      variant = EmailAddress.create!(teacher: from_teacher, email: "placeholder@example.com", primary: false)
      variant.update_column(:email, into_teacher.primary_email.upcase)

      expect { patch merge_path(from: from_teacher.id, into: into_teacher.id) }
        .to change { Teacher.exists?(from_teacher.id) }.from(true).to(false)

      emails = into_teacher.reload.email_addresses.pluck(:email)
      expect(emails).to match_array([into_teacher.primary_email, "short@long.com"])
      expect(EmailAddress.exists?(variant.id)).to be false
    end

    it "does not modify any records when previewing" do
      expect { get preview_merge_path(from: from_teacher.id, into: into_teacher.id) }
        .not_to change { EmailAddress.order(:id).pluck(:id, :teacher_id, :email) }
      expect(response).to be_successful
    end
  end

  context "for an admin" do
    before do
      log_in(admin_teacher)
    end

    it "renders the preview page successfully" do
      get preview_school_merge_path(from: from_school.id, into: into_school.id)
      expect(response).to be_successful
    end

    it "executes the merge: destroys from_school and redirects" do
      expect { patch school_merge_path(from: from_school.id, into: into_school.id) }
        .to change { School.exists?(from_school.id) }.from(true).to(false)
      expect(response).to redirect_to(schools_path)
      expect(flash[:notice]).to eq("Schools merged successfully.")
    end

    it "re-points teachers from the deleted school to the surviving school" do
      teacher = teachers(:bob) # belongs to berkeley (from_school)
      patch school_merge_path(from: from_school.id, into: into_school.id)
      expect(teacher.reload.school_id).to eq(into_school.id)
    end

    it "preserves the surviving school after merge" do
      patch school_merge_path(from: from_school.id, into: into_school.id)
      expect(School.exists?(into_school.id)).to be true
    end
  end
end
