# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeachersController, type: :controller do
  fixtures :all

  before(:each) do
    Rails.application.load_seed
    ApplicationController.any_instance.stub(:require_login).and_return(true)
  end

  describe "GET #index" do
    render_views

    it "hides the MailBluster sync column from the teachers index" do
      ApplicationController.any_instance.stub(:require_admin).and_return(true)

      get :index

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("MB Sync")
      expect(response.body).not_to include("Not Synced")
    end
  end

  describe "GET #deliverability_issues" do
    render_views

    it "shows non-admin teachers with suppressed or undelivered email addresses" do
      ApplicationController.any_instance.stub(:require_admin).and_return(true)
      email_addresses(:barney_personal_email1).update_columns(
        emails_sent: 4,
        emails_delivered: 1,
        suppressed_at: Time.current,
        suppression_reason: "hard_bounce",
        last_delivery_event_type: "bounce"
      )

      get :deliverability_issues

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Teacher Deliverability Issues")
      expect(response.body).to include("bigpurpletrex@gmail.com")
      expect(response.body).to include("Suppressed")
      expect(response.body).not_to include("validated@teacher.edu")
    end
  end

  it "should initialize session count to 1 when teachers signs up (submits app)" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    short_app = Teacher.find_by(first_name: "Short")
    post :create, params: { teacher: { first_name: "First", last_name: "Last", status: 0, education_level: 0,
                                       password: "pa33word!", more_info: "info", personal_website: "https://example.com",
                                       school_id: short_app.school_id },
                            email: { primary: "new@user.com" }
    }
    user = Teacher.find_by(first_name: "First")
    expect(user).not_to be_nil
    expect(user.session_count).to eq 1
  end

  it "should record ip address when teacher signs up (submits app)" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    short_app = Teacher.find_by(first_name: "Short")
    post :create, params: { teacher: { first_name: "First", last_name: "Last", status: 0, education_level: 0,
                                       password: "pa33word!", more_info: "info", personal_website: "https://example.com",
                                       school_id: short_app.school_id },
                            email: { primary: "new@user.com" }
    }
    user = Teacher.find_by(first_name: "First")
    expect(user).not_to be_nil
    expect(user.ip_history).to include(request.remote_ip)
  end

  it "persists verification_notes when a teacher submits a new application" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    short_app = Teacher.find_by(first_name: "Short")

    # Clarifying intent:
    # This verifies the end-to-end create path accepts and stores the new optional
    # verification_notes field (strong params + model assignment + persistence).
    post :create, params: { teacher: { first_name: "Verify", last_name: "Notes", status: 0, education_level: 0,
                                       password: "pa33word!", more_info: "info", personal_website: "www.example.com",
                                       verification_notes: "Principal contact: principal@example.edu",
                                       school_id: short_app.school_id },
                            email: { primary: "verify_notes_#{Time.now.to_i}@user.com" }
    }

    user = Teacher.find_by(first_name: "Verify", last_name: "Notes")
    expect(user).not_to be_nil
    expect(user.verification_notes).to eq("Principal contact: principal@example.edu")
  end

  it "should not increase session count when teacher attempts to sign up with existing email" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    short_app = Teacher.find_by(first_name: "Short")
    session_count_orig = short_app.session_count
    post :create, params: { teacher: { first_name: "Short", last_name: "Last", status: 0, education_level: 0,
                                       password: "pa33word!", more_info: "info", personal_website: "https://example.com",
                                       school_id: short_app.school_id },
                            email: { primary: short_app.primary_email }
    }
    expect(Teacher.find_by(first_name: "Short").session_count).to eq session_count_orig
  end

  it "able to deny an application" do
    ApplicationController.any_instance.stub(:require_admin).and_return(true)
    long_app = Teacher.find_by(first_name: "Short")
    post :deny, params: { id: long_app.id }
    long_app = Teacher.find_by(first_name: "Short")
    expect(long_app.display_application_status).to eq "Denied"
  end

  it "able to accept an application" do
    ApplicationController.any_instance.stub(:require_admin).and_return(true)
    long_app = Teacher.find_by(first_name: "Short")
    post :validate, params: { id: long_app.id }
    long_app = Teacher.find_by(first_name: "Short")
    expect(long_app.display_application_status).to eq "Validated"
  end

  it "able to delete an application" do
    ApplicationController.any_instance.stub(:require_admin).and_return(true)
    ApplicationController.any_instance.stub(:is_admin?).and_return(true)
    long_app = Teacher.find_by(first_name: "Short")
    delete :destroy, params: { id: long_app.id }
    expect(Teacher.find_by(first_name: "Short")).to be_nil
  end

  it "deletes MailBluster lead when destroying a teacher" do
    ApplicationController.any_instance.stub(:require_admin).and_return(true)
    ApplicationController.any_instance.stub(:is_admin?).and_return(true)
    teacher = Teacher.find_by(first_name: "Short")
    allow(MailblusterService).to receive(:configured?).and_return(true)
    expect(MailblusterService).to receive(:delete_lead).with(teacher.primary_email)

    delete :destroy, params: { id: teacher.id }
  end

  it "doesn't allow teacher to delete an application" do
    long_app = Teacher.find_by(first_name: "Short")
    delete :destroy, params: { id: long_app.id }
    expect(Teacher.find_by(first_name: "Short")).not_to be_nil
  end

  it "appends ip address when teacher updates info for themselves without repetition" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Short"))
    short_app = Teacher.find_by(first_name: "Short")
    post :update, params: { id: short_app.id, teacher: { id: short_app.id, more_info: "changed", school_id: short_app.school_id } }
    short_app = Teacher.find_by(first_name: "Short")
    expect(short_app.more_info).to eq "changed"
    expect(short_app.ip_history).to include request.remote_ip
  end

  it "doesn't appends same ip address twice even if teacher updates twice" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Short"))
    short_app = Teacher.find_by(first_name: "Short")
    post :update, params: { id: short_app.id, teacher: { id: short_app.id, more_info: "changed", school_id: short_app.school_id } }
    short_app = Teacher.find_by(first_name: "Short")
    expect(short_app.more_info).to eq "changed"
    cur_ip_count = short_app.ip_history.count()
    post :update, params: { id: short_app.id, teacher: { id: short_app.id, more_info: "changed again", school_id: short_app.school_id } }
    short_app = Teacher.find_by(first_name: "Short")
    expect(short_app.more_info).to eq "changed again"
    expect(short_app.ip_history.count()).to eq cur_ip_count
  end

  it "doesn't appends ip address when admin updates teacher's info" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(true)
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Short"))
    short_app = Teacher.find_by(first_name: "Short")
    ip_count = short_app.ip_history.count()
    post :update, params: { id: short_app.id, teacher: { id: short_app.id, snap: "foobar", school_id: short_app.school_id } }
    short_app = Teacher.find_by(first_name: "Short")
    expect(short_app.snap).to eq "foobar"
    expect(short_app.ip_history.count()).to eq ip_count
  end

  it "allows a teacher to update verification_notes on their own profile" do
    ApplicationController.any_instance.stub(:require_edit_permission).and_return(true)
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Short"))
    short_app = Teacher.find_by(first_name: "Short")

    # Clarifying intent:
    # This checks the edit/update path for existing teachers and ensures
    # verification_notes remains writable for normal self-service profile updates.
    post :update, params: {
      id: short_app.id,
      teacher: {
        id: short_app.id,
        verification_notes: "Homeschool verification via district office",
        school_id: short_app.school_id
      }
    }

    short_app = Teacher.find_by(first_name: "Short")
    expect(short_app.verification_notes).to eq("Homeschool verification via district office")
  end

  it "doesn't allow teacher to change their snap or email" do
    ApplicationController.any_instance.stub(:require_edit_permission).and_return(true)
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Short"))
    short_app = Teacher.find_by(first_name: "Short")
    post :update, params: { id: short_app.id, teacher: { id: short_app.id, email: "wrong@berkeley.edu", school_id: short_app.school_id } }
    post :update, params: { id: short_app.id, teacher: { id: short_app.id, snap: "wrong", school_id: short_app.school_id } }
    short_app = Teacher.find_by(first_name: "Short")
    expect(short_app.primary_email).to eq "short@long.com"
    expect(short_app.snap).to eq "song"
  end

  it "resend a welcome_email for validated teacher" do
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Ye"))
    short_app = Teacher.find_by(first_name: "Ye")
    post :resend_welcome_email, params: { id: short_app.id }
    last_email = ActionMailer::Base.deliveries.last
    expect(last_email.subject).to eq "Welcome to The Beauty and Joy of Computing!"
  end

  it "denied and not_reviewed teacher can not request welcome email" do
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Bob"))
    bob_app = Teacher.find_by(first_name: "Bob")
    post :resend_welcome_email, params: { id: bob_app.id }
    expect(ActionMailer::Base.deliveries).to be_empty
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Short"))
    short_app = Teacher.find_by(first_name: "Short")
    post :resend_welcome_email, params: { id: short_app.id }
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "denied teacher cannot edit their application" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Bob"))
    bob_app = Teacher.find_by(first_name: "Bob")
    orig_more_info = bob_app.more_info
    post :update, params: { id: bob_app.id, teacher: { id: bob_app.id, more_info: "changed", school_id: bob_app.school_id } }
    bob_app = Teacher.find_by(first_name: "Bob")
    expect(bob_app.more_info).to eq orig_more_info
  end

  context "malicious parameters" do
    it "does not allow non-admin to accept a user" do
      post :validate, params: { id: 1 }
      expect(response).to have_http_status(302)
      expect(response).to redirect_to(login_path)
      expect(flash[:danger]).to eq "Please log in to access this page."
    end

    it "rejects malicious admin signup attempt" do
      post :create, params: {
        teacher: {
          first_name: "Valid",
          last_name: "Example",
          status: 0,
          snap: "valid_example",
          admin: true,
          personal_website: "https://example.com",
          school_id: School.first.id
        },
        email: {
          primary: "valid_example@validexample.edu",
        }
      }

      email_address = EmailAddress.find_by(email: "valid_example@validexample.edu")
      expect(email_address).not_to be_nil
      teacher = email_address.teacher
      expect(teacher.admin).to be(false)
    end

    it "rejects malicious auto-approve signup attempt" do
      post :create, params: {
        teacher: {
          first_name: "Valid",
          last_name: "Example",
          status: 0,
          application_status: "validated",
          snap: "valid_example",
          personal_website: "https://example.com",
          school_id: School.first.id,
        },
        email: {
          primary: "valid_example@validexample.edu",
        }
      }
      email_address = EmailAddress.find_by(email: "valid_example@validexample.edu")
      expect(email_address).not_to be_nil
      teacher = email_address.teacher
      expect(teacher.not_reviewed?).to be(true)
    end
  end

  context "flash a message after resend_welcome_email" do
    it "succeeds when teacher is validated, sets success" do
      validated_teacher = Teacher.find_by(first_name: "Validated")
      ApplicationController.any_instance.stub(:current_user).and_return(validated_teacher)
      request.env["HTTP_REFERER"] = edit_teacher_path(validated_teacher.id)
      post :resend_welcome_email, params: { id: validated_teacher.id }
      expect(flash[:success]).to eq("Welcome email resent successfully!")
      expect(response).to redirect_to(edit_teacher_path(validated_teacher.id))
    end

    it "fails when teacher is not validated, sets alert" do
      nonvalidated_teacher = Teacher.find_by(first_name: "Short")
      ApplicationController.any_instance.stub(:current_user).and_return(nonvalidated_teacher)
      request.env["HTTP_REFERER"] = teacher_path(nonvalidated_teacher.id)
      post :resend_welcome_email, params: { id: nonvalidated_teacher.id }
      expect(flash[:alert]).to eq("Error resending welcome email. Please ensure that your account has been validated by an administrator.")
      expect(response).to redirect_to(teacher_path(nonvalidated_teacher.id))
    end
  end

  describe "GET #show" do
    let(:teacher) { double("Teacher", id: 1) }
    let(:other_teacher) { double("Teacher") }
    let(:school) { double("School") }

    before do
      ApplicationController.any_instance.stub(:require_login).and_return(true)
      ApplicationController.any_instance.stub(:require_admin).and_return(true)
      allow(Teacher).to receive(:find).and_return(teacher)
      allow(Teacher).to receive_message_chain(:where, :not).and_return(other_teacher)
      allow(teacher).to receive(:school).and_return(school)
    end

    it "assigns admin if teacher is admin" do
      allow(controller).to receive(:is_admin?).and_return(true)
      get :show, params: { id: 1 }
      expect(assigns(:school)).to eq(school)
      expect(assigns(:status)).to eq("Admin")
      expect(response).to render_template("show")
    end
  end

  describe "GET #new" do
    let(:teacher) { double("Teacher") }
    let(:school) { double("School") }
    # Does not check omniauth if-loop
    let(:omniauth_data) { double("OmniauthData", present?: false) }

    before do
      ApplicationController.any_instance.stub(:require_login).and_return(true)
      allow(Teacher).to receive(:new).and_return(teacher)
      allow(School).to receive(:new).and_return(school)
      allow(teacher).to receive(:school=).and_return(school)
      allow(teacher).to receive(:school).and_return(school)
      allow(controller).to receive(:ordered_schools).and_return(nil)
      allow(controller).to receive(:omniauth_data).and_return(omniauth_data)
    end

    it "sets up teacher, school, and readonly" do
      get :new
      expect(assigns(:teacher)).to eq(teacher)
      expect(assigns(:school)).to eq(school)
      expect(assigns(:readonly)).to be_falsey
      expect(response).to render_template("new")
    end
  end

  describe "GET #cross_filter_search" do
    before do
      ApplicationController.any_instance.stub(:require_admin).and_return(true)
    end

    context "action is reachable" do
      it "responds with 200 OK" do
        get :cross_filter_search, params: { q: "anything" }
        expect(response).to have_http_status(:ok)
      end

      it "responds with JSON content type" do
        get :cross_filter_search, params: { q: "anything" }
        expect(response.content_type).to match(%r{application/json})
      end
    end

    context "returns status counts as display values" do
      before do
        fake_relation = double("ActiveRecord::Relation")
        allow(Teacher).to receive(:search_non_admins).and_return(fake_relation)
        allow(fake_relation).to receive(:reorder).and_return(fake_relation)
        allow(fake_relation).to receive(:group).and_return(fake_relation)
        allow(fake_relation).to receive(:count).and_return({ "denied" => 2, "validated" => 1 })
      end

      it "returns display values as keys in the JSON response" do
        get :cross_filter_search, params: { q: "test" }
        body = JSON.parse(response.body)
        expect(body).to eq({ "Denied" => 2, "Validated" => 1 })
      end

      it "omits statuses with zero count" do
        get :cross_filter_search, params: { q: "test" }
        body = JSON.parse(response.body)
        expect(body.keys).not_to include("Info Needed", "Not Reviewed")
      end
    end
  end

  describe "GET #edit" do
    let(:teacher) { instance_double("Teacher", id: 1, school:) }
    let(:school) { instance_double("School") }

    before do
      ApplicationController.any_instance.stub(:require_edit_permission).and_return(true)
      allow(controller).to receive(:ordered_schools)
      allow(Teacher).to receive(:find).and_return(teacher)
    end

    it "sets user as admin" do
      allow(controller).to receive(:is_admin?).and_return(true)
      get :edit, params: { id: teacher.id }
      expect(assigns(:school)).to eq(school)
      expect(assigns(:status)).to eq("Admin")
      expect(assigns(:readonly)).to be_falsey
      expect(response).to render_template("edit")
    end

    it "sets user as teacher" do
      allow(controller).to receive(:is_admin?).and_return(false)
      get :edit, params: { id: teacher.id }
      expect(assigns(:school)).to eq(school)
      expect(assigns(:status)).to eq("Teacher")
      expect(assigns(:readonly)).to be_truthy
      expect(response).to render_template("edit")
    end
  end

  describe "MailBluster sync actions" do
    before(:each) do
      ApplicationController.any_instance.stub(:require_admin).and_return(true)
      ApplicationController.any_instance.stub(:is_admin?).and_return(true)
    end

    describe "POST #sync_mailbluster" do
      let(:teacher) { Teacher.find_by(first_name: "Validated") }

      it "syncs a single teacher when API key is configured" do
        allow(MailblusterService).to receive(:configured?).and_return(true)
        allow(MailblusterService).to receive(:sync_teacher).with(teacher).and_return({ success: true })

        post :sync_mailbluster, params: { id: teacher.id }
        expect(response).to redirect_to(teacher_path(teacher))
        expect(flash[:notice]).to include("Successfully synced")
      end

      it "shows error when sync fails" do
        allow(MailblusterService).to receive(:configured?).and_return(true)
        allow(MailblusterService).to receive(:sync_teacher).with(teacher).and_return({ success: false, error: "API error" })

        post :sync_mailbluster, params: { id: teacher.id }
        expect(response).to redirect_to(teacher_path(teacher))
        expect(flash[:alert]).to include("Failed to sync")
      end

      it "shows error when API key is not configured" do
        allow(MailblusterService).to receive(:configured?).and_return(false)

        post :sync_mailbluster, params: { id: teacher.id }
        expect(response).to redirect_to(teacher_path(teacher))
        expect(flash[:alert]).to include("not configured")
      end
    end

    describe "POST #sync_all_mailbluster" do
      it "syncs all teachers and shows results" do
        allow(MailblusterService).to receive(:configured?).and_return(true)
        allow(MailblusterService).to receive(:sync_all_teachers).and_return(
          { synced: 5, failed: 1, skipped: 0, errors: ["Teacher 99 (Test)"] }
        )

        post :sync_all_mailbluster
        expect(response).to redirect_to(teachers_path)
        expect(flash[:notice]).to include("5 synced")
        expect(flash[:notice]).to include("1 failed")
      end

      it "shows errors from sync" do
        allow(MailblusterService).to receive(:configured?).and_return(true)
        allow(MailblusterService).to receive(:sync_all_teachers).and_return(
          { synced: 0, failed: 2, skipped: 0, errors: ["Teacher 1: error", "Teacher 2: error"] }
        )

        post :sync_all_mailbluster
        expect(flash[:alert]).to include("Errors:")
      end

      it "shows error when API key is not configured" do
        allow(MailblusterService).to receive(:configured?).and_return(false)

        post :sync_all_mailbluster
        expect(response).to redirect_to(teachers_path)
        expect(flash[:alert]).to include("not configured")
      end
    end
  end

  describe "POST #validate with MailBluster sync" do
    before(:each) do
      ApplicationController.any_instance.stub(:require_admin).and_return(true)
      ApplicationController.any_instance.stub(:is_admin?).and_return(true)
    end

    it "syncs teacher to MailBluster when approving" do
      teacher = Teacher.find_by(first_name: "Short")
      allow(MailblusterService).to receive(:configured?).and_return(true)
      expect(MailblusterService).to receive(:create_or_update_lead).with(teacher)

      post :validate, params: { id: teacher.id }
    end

    it "does not sync when API key is not configured" do
      teacher = Teacher.find_by(first_name: "Short")
      allow(MailblusterService).to receive(:configured?).and_return(false)
      expect(MailblusterService).not_to receive(:create_or_update_lead)

      post :validate, params: { id: teacher.id }
    end
  end

  describe "PUT #update with MailBluster auto-sync on status change" do
    before(:each) do
      ApplicationController.any_instance.stub(:require_admin).and_return(true)
      ApplicationController.any_instance.stub(:require_edit_permission).and_return(true)
      ApplicationController.any_instance.stub(:is_admin?).and_return(true)
      ApplicationController.any_instance.stub(:current_user).and_return(Teacher.find_by(first_name: "Ye"))
    end

    it "syncs to MailBluster when application_status changes to validated" do
      teacher = Teacher.find_by(first_name: "Short")
      allow(MailblusterService).to receive(:configured?).and_return(true)
      expect(MailblusterService).to receive(:create_or_update_lead)

      put :update, params: {
        id: teacher.id,
        teacher: { application_status: "validated", school_id: teacher.school_id },
        skip_email: "Yes"
      }
    end

    it "does not sync when status does not change" do
      teacher = Teacher.find_by(first_name: "Validated")
      allow(MailblusterService).to receive(:configured?).and_return(true)
      expect(MailblusterService).not_to receive(:create_or_update_lead)

      put :update, params: {
        id: teacher.id,
        teacher: { first_name: "StillValidated", school_id: teacher.school_id },
        skip_email: "Yes"
      }
    end
  end
end
