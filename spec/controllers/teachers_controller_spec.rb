# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeachersController, type: :controller do
  fixtures :all

  before(:each) do
    Rails.application.load_seed
    ApplicationController.any_instance.stub(:require_login).and_return(true)
  end

  it "should initialize session count to 1 when teachers signs up (submits app)" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    short_app = Teacher.find_by(first_name: "Short")
    post :create, params: { teacher: { first_name: "First", last_name: "Last", status: 0, education_level: 0,
                                       password: "pa33word!", more_info: "info",
                                       school_id: short_app.school_id, personal_website: "https://www.example.edu" },
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
                                       password: "pa33word!", more_info: "info",
                                       school_id: short_app.school_id, personal_website: "https://www.example.edu" },
                            email: { primary: "new@user.com" }
    }
    user = Teacher.find_by(first_name: "First")
    expect(user).not_to be_nil
    expect(user.ip_history).to include(request.remote_ip)
  end

  it "should not increase session count when teacher attempts to sign up with existing email" do
    ApplicationController.any_instance.stub(:is_admin?).and_return(false)
    short_app = Teacher.find_by(first_name: "Short")
    session_count_orig = short_app.session_count
    post :create, params: { teacher: { first_name: "Short", last_name: "Last", status: 0, education_level: 0,
                                       password: "pa33word!", more_info: "info",
                                       school_id: short_app.school_id, personal_website: "https://www.example.edu" },
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
      expect(response).to redirect_to(root_path)
      expect(flash[:danger]).to eq "Only admins can access this page."
    end

    it "rejects malicious admin signup attempt" do
      post :create, params: {
        teacher: {
          first_name: "Valid",
          last_name: "Example",
          status: 0,
          snap: "valid_example",
          admin: true,
          school_id: School.first.id,
          personal_website: "https://www.validexample.edu"
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
          school_id: School.first.id,
          personal_website: "https://www.validexample.edu"
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
end
