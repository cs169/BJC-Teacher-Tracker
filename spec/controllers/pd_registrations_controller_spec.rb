# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PdRegistrations", type: :request do
  fixtures :all

  let(:admin_user) { teachers(:admin) }
  let(:regular_user) { teachers(:validated_teacher) }
  let(:professional_development) { ProfessionalDevelopment.create!(name: "Effective Teaching Strategies", city: "City", state: "State", country: "Country", start_date: Date.today, end_date: Date.tomorrow, grade_level: "university") }
  let(:teacher1) { teachers(:bob) }
  let(:teacher2) { teachers(:long) }
  let(:valid_registration_attributes) {
    {
      teacher_id: teacher1.id,
      attended: true,
      role: "attendee"
    }
  }
  let(:valid_registration_attributes2) {
    {
      teacher_id: teacher2.id,
      attended: true,
      role: "attendee"
    }
  }
  let(:invalid_registration_attributes) {
    {
      teacher_id: nil,
      attended: false,
      role: ""
    }
  }
  let!(:pd_registration) { PdRegistration.create!(valid_registration_attributes.merge(professional_development_id: professional_development.id)) }

  describe "Authorization" do
    shared_examples "admin access" do
      it "allows operation for admin" do
        log_in(admin_user)
        action
        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to match(/successfully/)
      end
    end

    shared_examples "unauthorized access" do
      it "denies operation for regular user" do
        log_in(regular_user)
        action
        expect(response).to redirect_to(root_path)
        expect(flash[:danger]).to be_present
      end
    end

    describe "CREATE" do
      let(:action) { post professional_development_pd_registrations_path(professional_development), params: { pd_registration: valid_registration_attributes2 } }
      include_examples "admin access"
      include_examples "unauthorized access"
    end

    describe "UPDATE" do
      let(:action) { patch professional_development_pd_registration_path(professional_development, pd_registration), params: { pd_registration: { role: "leader" } } }
      include_examples "admin access"
      include_examples "unauthorized access"
    end

    describe "DELETE" do
      let(:action) { delete professional_development_pd_registration_path(professional_development, pd_registration) }
      include_examples "admin access"
      include_examples "unauthorized access"
    end
  end

  describe "Admin operations" do
    before { log_in(admin_user) }

    describe "CREATE" do
      context "with valid attributes" do
        it "creates a new registration successfully" do
          expect {
            post professional_development_pd_registrations_path(professional_development), params: { pd_registration: valid_registration_attributes2 }
          }.to change(PdRegistration, :count).by(1)
          expect(response).to redirect_to(professional_development_path(professional_development))
          expect(flash[:notice]).to match(/successfully created/)
        end
      end

      context "with invalid attributes" do
        it "fails to create and renders errors" do
          post professional_development_pd_registrations_path(professional_development), params: { pd_registration: invalid_registration_attributes }
          expect(response).to render_template("professional_developments/show")
          expect(flash.now[:alert]).to be_present
        end
      end
    end

    describe "UPDATE" do
      context "with valid attributes" do
        it "updates the registration successfully" do
          patch professional_development_pd_registration_path(professional_development, pd_registration), params: { pd_registration: { role: "leader" } }
          expect(response).to redirect_to(professional_development_path(professional_development))
          expect(flash[:notice]).to match(/successfully updated/)
        end
      end

      context "with invalid attributes" do
        it "fails to update and renders errors" do
          patch professional_development_pd_registration_path(professional_development, pd_registration), params: { pd_registration: invalid_registration_attributes }
          expect(response).to render_template("professional_developments/show")
          expect(flash.now[:alert]).to include("Teacher must exist and Role  is not a valid role")
        end
      end

      it "cannot move a registration to a different professional development" do
        other_pd = ProfessionalDevelopment.create!(name: "Other PD", city: "City", state: "State",
                                                   country: "Country", start_date: Date.today,
                                                   end_date: Date.tomorrow, grade_level: "university")
        patch professional_development_pd_registration_path(professional_development, pd_registration),
              params: { pd_registration: { role: "leader", professional_development_id: other_pd.id } }
        pd_registration.reload
        expect(pd_registration.professional_development_id).to eq(professional_development.id)
        expect(pd_registration.role).to eq("leader")
      end
    end

    describe "DELETE" do
      context "when deletion is successful" do
        it "deletes the registration successfully and redirects" do
          expect {
            delete professional_development_pd_registration_path(professional_development, pd_registration)
          }.to change(PdRegistration, :count).by(-1)
          expect(response).to redirect_to(professional_development_path(professional_development))
          expect(flash[:notice]).to match(/successfully cancelled/)
        end
      end

      context "when attempting to delete a non-existent registration" do
        it "does not change the count of registrations and redirects with an error" do
          expect {
            # using -1 to simulate a non-existent ID
            delete professional_development_pd_registration_path(professional_development, -1)
          }.not_to change(PdRegistration, :count)
          expect(response).to redirect_to(professional_development_path)
          expect(flash[:alert]).to match("Registration not found.")
        end
      end
    end
  end
end
