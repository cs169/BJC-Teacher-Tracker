# frozen_string_literal: true

require "rails_helper"

# Regression tests: import, request_info, upload_file, and remove_file were
# previously reachable by any logged-in teacher, allowing bulk data changes,
# status flips, and file tampering on other teachers' records.
RSpec.describe TeachersController, type: :request do
  fixtures :all

  let(:admin) { teachers(:admin) }
  let(:teacher) { teachers(:validated_teacher) }
  let(:other_teacher) { teachers(:long) }

  describe "POST /teachers/import" do
    it "is denied for a non-admin teacher" do
      log_in(teacher)
      expect {
        post import_teachers_path, params: { file: fixture_file_upload(Rails.root.join("spec/fixtures/test_file.txt"), "text/csv") }
      }.not_to change { Teacher.count }
      expect(response).to redirect_to(root_path)
      expect(flash[:danger]).to eq("Only admins can access this page.")
    end

    it "is denied when logged out" do
      post import_teachers_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "POST /teachers/:id/request_info" do
    it "is denied for a non-admin teacher acting on another teacher" do
      log_in(teacher)
      expect {
        post request_info_teacher_path(other_teacher), params: { request_reason: "gimme" }
      }.not_to change { other_teacher.reload.application_status }
      expect(response).to redirect_to(root_path)
    end

    it "is allowed for an admin" do
      log_in(admin)
      post request_info_teacher_path(other_teacher), params: { skip_email: "on" }
      expect(other_teacher.reload.application_status).to eq("info_needed")
    end
  end

  describe "file upload/removal" do
    it "denies uploading a file to another teacher's record" do
      log_in(teacher)
      expect {
        post upload_file_teacher_path(other_teacher), params: { file: fixture_file_upload(Rails.root.join("spec/fixtures/test_file.txt"), "text/plain") }
      }.not_to change { other_teacher.files.count }
      expect(response).to redirect_to(edit_teacher_path(teacher.id))
      expect(flash[:alert]).to eq("You can only edit your own information")
    end

    it "denies removing another teacher's file" do
      other_teacher.files.attach(fixture_file_upload(Rails.root.join("spec/fixtures/test_file.txt"), "text/plain"))
      file_id = other_teacher.files.first.id

      log_in(teacher)
      expect {
        delete remove_file_teacher_path(other_teacher, file_id:)
      }.not_to change { other_teacher.files.count }
      expect(response).to redirect_to(edit_teacher_path(teacher.id))
    end

    it "allows a teacher to upload and remove their own file" do
      log_in(teacher)
      post upload_file_teacher_path(teacher), params: { file: fixture_file_upload(Rails.root.join("spec/fixtures/test_file.txt"), "text/plain") }
      expect(teacher.files.count).to eq(1)

      delete remove_file_teacher_path(teacher, file_id: teacher.files.first.id)
      expect(teacher.reload.files.count).to eq(0)
    end

    it "allows an admin to remove any teacher's file" do
      other_teacher.files.attach(fixture_file_upload(Rails.root.join("spec/fixtures/test_file.txt"), "text/plain"))
      log_in(admin)
      expect {
        delete remove_file_teacher_path(other_teacher, file_id: other_teacher.files.first.id)
      }.to change { other_teacher.files.count }.from(1).to(0)
    end
  end
end
