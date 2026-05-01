# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmailTemplatesController, type: :controller do
  fixtures :all

  before(:each) do
    Rails.application.load_seed
  end

  it "ERB is not rendered in email templates" do
    allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
    welcome_email = EmailTemplate.find_by(path: "teacher_mailer/welcome_email")
    post :update, params: { id: welcome_email.id, email_template: { id: welcome_email.id, body: "<%= @teacher.first_name %>" } }
    teacher = teachers(:bob)
    email = TeacherMailer.welcome_email(teacher)
    email.deliver_now
    expect(email.body.encoded).to include("@teacher.first_name")
  end

  it "should allow liquid variables" do
    allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
    welcome_email = EmailTemplate.find_by(path: "teacher_mailer/welcome_email")
    post :update, params: { id: welcome_email.id, email_template: { id: welcome_email.id, body: "Welcome to BJC, {{teacher_first_name}}" } }
    teacher = teachers(:bob)
    email = TeacherMailer.welcome_email(teacher)
    email.deliver_now
    expect(email.body.encoded).to include("Welcome to BJC, Bob")
  end

  it "should allow edit email subject" do
    allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
    welcome_email = EmailTemplate.find_by(path: "teacher_mailer/welcome_email")
    post :update, params: { id: welcome_email.id, email_template: { id: welcome_email.id, subject: "Test Subject" } }
    teacher = teachers(:bob)
    email = TeacherMailer.welcome_email(teacher)
    email.deliver_now
    expect(email.subject).to eq("Test Subject")
  end

  describe "GET #new" do
    it "assigns a new email template and renders new" do
      allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
      get :new
      expect(assigns(:email_template)).to be_a_new(EmailTemplate)
      expect(response).to render_template(:new)
    end
  end

  describe "DELETE #destroy" do
    it "destroys, redirects, and sets notice flash message" do
      allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
      new_email_template = double("EmailTemplate")
      allow(EmailTemplate).to receive(:destroy).with("1").and_return(new_email_template)
      allow(new_email_template).to receive(:destroy).and_return(nil)
      get :destroy, params: { id: 1 }
      expect(flash[:notice]).to be_present
      expect(response).to redirect_to(email_templates_path)
    end
  end

  describe "GET #index" do
    it "loads email templates ordered by title" do
      allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
      email_template1 = double("EmailTemplate", title: "Template A")
      email_template2 = double("EmailTemplate", title: "Template C")
      email_template3 = double("EmailTemplate", title: "Template B")
      ordered_templates = [email_template1, email_template3, email_template2]
      allow(EmailTemplate).to receive_message_chain(:all, :order).with(:title).and_return(ordered_templates)
      get :index
      loaded_templates = controller.instance_variable_get(:@ordered_email_templates)
      expect(loaded_templates).to eq([email_template1, email_template3, email_template2])
    end
  end

  describe "GET #edit" do
    it "loads the requested email template" do
      allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
      fake_email_template = double("EmailTemplate")
      allow(EmailTemplate).to receive(:find).and_return(fake_email_template)
      get :edit, params: { id: 1 }
      expect(assigns(:email_template)).to eq(fake_email_template)
    end
  end

  describe "PUT #update" do
    let(:template_params) { { title: "Updated Template", body: "Updated Body", subject: "Updated Subject", to: "updated@example.com" } }
    let(:email_template) { double("EmailTemplate", id: 1, title: "New Email Template") }

    before do
      allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
      allow(EmailTemplate).to receive(:find).with(email_template.id.to_s).and_return(email_template)
    end

    it "successfully updates and redirects to email templates" do
      allow(email_template).to receive(:update).with(hash_including(template_params)).and_return(true)
      allow(email_template).to receive(:save).and_return(true)
      put :update, params: { id: email_template.id, email_template: template_params }
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(email_templates_path)
    end

    it "fails to update and renders edit" do
      allow(email_template).to receive(:update).with(hash_including(template_params)).and_return(false)
      allow(email_template).to receive(:save).and_return(false)
      allow(email_template).to receive_message_chain(:errors, :full_messages, :join).and_return(["Error message"])
      put :update, params: { id: email_template.id, email_template: template_params }
      expect(flash[:alert]).to be_present
      expect(response).to render_template("edit")
    end
  end

  describe "POST #create" do
    let(:template_params) { { title: "Test Template", body: "Body", subject: "Subject", to: "example@example.com" } }
    let(:new_email_template) { double("EmailTemplate") }

    before do
      allow_any_instance_of(ApplicationController).to receive(:is_admin?).and_return(true)
      allow(new_email_template).to receive(:save).and_return(true)
      allow(new_email_template).to receive(:title).and_return("Test Template")
    end

    it "updates an existing email template" do
      allow(EmailTemplate).to receive(:find_by).with(title: template_params[:title]).and_return(new_email_template)
      allow(new_email_template).to receive(:assign_attributes).and_return(new_email_template)
      post :create, params: { email_template: template_params }
      expect(assigns(:email_template)).to eq(new_email_template)
    end

    it "creates a new email template" do
      allow(EmailTemplate).to receive(:find_by).with(title: template_params[:title]).and_return(nil)
      allow(EmailTemplate).to receive(:new).and_return(new_email_template)
      post :create, params: { email_template: template_params }
      expect(assigns(:email_template)).to eq(new_email_template)
    end

    it "sets success flash message" do
      allow_any_instance_of(EmailTemplate).to receive(:save).and_return(true)
      post :create, params: { email_template: template_params }
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(email_templates_path)
    end

    it "re-renders new with error message" do
      allow_any_instance_of(EmailTemplate).to receive(:save).and_return(false)
      allow_any_instance_of(EmailTemplate).to receive_message_chain(:errors, :full_messages, :join).and_return(["Error message"])
      post :create, params: { email_template: template_params }
      expect(flash[:alert]).to be_present
      expect(response).to render_template("new")
    end
  end
end
