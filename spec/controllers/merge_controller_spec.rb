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
      expect(response).to redirect_to(root_path)
    end

    it "redirects execute to root" do
      patch school_merge_path(from: from_school.id, into: into_school.id)
      expect(response).to redirect_to(root_path)
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
