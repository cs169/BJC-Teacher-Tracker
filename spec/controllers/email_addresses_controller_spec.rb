# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailAddress, type: :model do
  describe "validations" do
    it "is invalid with an incorrect email format" do
      teacher = Teacher.create(first_name: "John", last_name: "Doe", admin: false)
      email_address = EmailAddress.new(email: "invalid-email", teacher:, primary: false)

      expect(email_address.valid?).to be false
      expect(email_address.errors[:email]).to include("is invalid")
    end

    it "is invalid without an email" do
      teacher = Teacher.create(first_name: "John", last_name: "Doe", admin: false)
      email_address = EmailAddress.new(teacher:, primary: false)

      expect(email_address.valid?).to be false
      expect(email_address.errors[:email]).to include("can't be blank")
    end

    it "is valid with a correct email format" do
      teacher = Teacher.create(first_name: "John", last_name: "Doe", admin: false)
      email_address = EmailAddress.new(email: "valid.email@berkeley.edu", teacher:, primary: false)

      expect(email_address.valid?).to be true
    end
  end
end

RSpec.describe EmailAddressesController, type: :controller do
  fixtures :all

  before(:each) do
    Rails.application.load_seed
    ApplicationController.any_instance.stub(:require_login).and_return(true)
    ApplicationController.any_instance.stub(:require_admin).and_return(true)
    ApplicationController.any_instance.stub(:is_admin?).and_return(true)
  end

  describe "POST #create with MailBluster sync" do
    let(:teacher) { teachers(:validated_teacher) }

    it "syncs teacher to MailBluster when adding email to validated teacher" do
      allow(MailblusterService).to receive(:configured?).and_return(true)
      expect(MailblusterService).to receive(:create_or_update_lead).with(teacher)

      post :create, params: { teacher_id: teacher.id, email: "newemail@test.com" }
    end

    it "does not sync when teacher is not validated" do
      denied_teacher = teachers(:bob) # bob has application_status: Denied
      allow(MailblusterService).to receive(:configured?).and_return(true)
      expect(MailblusterService).not_to receive(:create_or_update_lead)

      post :create, params: { teacher_id: denied_teacher.id, email: "newemail2@test.com" }
    end

    it "does not sync when API key is not configured" do
      allow(MailblusterService).to receive(:configured?).and_return(false)
      expect(MailblusterService).not_to receive(:create_or_update_lead)

      post :create, params: { teacher_id: teacher.id, email: "newemail3@test.com" }
    end
  end

  describe "DELETE #destroy with MailBluster sync" do
    let(:teacher) { teachers(:validated_teacher) }

    it "re-syncs teacher to MailBluster when deleting an email" do
      extra_email = teacher.email_addresses.create!(email: "extra_mb@test.com", primary: false)
      allow(MailblusterService).to receive(:configured?).and_return(true)
      expect(MailblusterService).to receive(:create_or_update_lead).with(teacher)

      delete :destroy, params: { teacher_id: teacher.id, id: extra_email.id }
    end

    it "does not sync when teacher is not validated" do
      denied_teacher = teachers(:bob)
      extra_email = denied_teacher.email_addresses.create!(email: "extra_mb2@test.com", primary: false)
      allow(MailblusterService).to receive(:configured?).and_return(true)
      expect(MailblusterService).not_to receive(:create_or_update_lead)

      delete :destroy, params: { teacher_id: denied_teacher.id, id: extra_email.id }
    end
  end
end
