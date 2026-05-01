# frozen_string_literal: true

require "rails_helper"

describe TeacherMailer do
  fixtures :all

  before(:all) do
    Rails.application.load_seed
  end
  it "Sends Welcome Email" do
     teacher = teachers(:bob)
     email = TeacherMailer.welcome_email(teacher)
     email.deliver_now
     expect(email.from).to include("contact@bjc.berkeley.edu")
     expect(email.to).to include("bob@gmail.com")
     expect(email.subject).to eq("Welcome to The Beauty and Joy of Computing!")
     expect(email.body.encoded).to include("Hi Bob")
   end

  it "Sends to Both School and Personal Email When Possible" do
   teacher = teachers(:barney)
   email = TeacherMailer.welcome_email(teacher)
   email.deliver_now
   expect(email.from).to include("contact@bjc.berkeley.edu")
   expect(email.to).to include("barneydinosaur@gmail.com")
   expect(email.to).to include("bigpurpletrex@gmail.com")
   expect(email.subject).to eq("Welcome to The Beauty and Joy of Computing!")
   expect(email.body.encoded).to include("Hi Barney")
 end


  it "Sends Deny Email" do
    teacher = teachers(:long)
    email = TeacherMailer.deny_email(teacher, "Denial Reason")
    email.deliver_now
    expect(email.from).to include("contact@bjc.berkeley.edu")
    expect(email.to).to include("short@long.com")
    expect(email.subject).to eq("Deny Email")
    expect(email.body.encoded).to include("Denial Reason")
  end

  it "Sends Form Submission Email" do
    teacher = teachers(:long)
    email = TeacherMailer.form_submission(teacher)
    email.deliver_now
    expect(email.from).to include("contact@bjc.berkeley.edu")
    expect(email.to).to include("lmock@berkeley.edu")
    expect(email.body.encoded).to include("View form submission")
    expect(email.body.encoded).to include("Short Long")
  end

  it "renders view_teacher_url in Form Submission email" do
    teacher = teachers(:long)
    email = TeacherMailer.form_submission(teacher)
    email.deliver_now

    expect(email.body.encoded).to include(Rails.application.routes.url_helpers.teacher_url(teacher))
    expect(email.body.encoded).not_to include("{{view_teacher_url}}")
  end

  it "Sends Request Info Email" do
    teacher = teachers(:long)
    email = TeacherMailer.request_info_email(teacher, "Request Reason")
    email.deliver_now
    expect(email.from).to include("contact@bjc.berkeley.edu")
    expect(email.to).to include("short@long.com")
    expect(email.subject).to eq("Request Info Email")
    # Test appearance of first_name
    expect(email.body.encoded).to include("Short")
    expect(email.body.encoded).to include("Request Reason")
    expect(email.body.encoded).to include("We're writing to you regarding your ongoing application with BJC.")
  end

  it "Sends Teacher Form Submission Email" do
    teacher = teachers(:long)
    email = TeacherMailer.teacher_form_submission(teacher)
    email.deliver_now
    expect(email.from).to include("contact@bjc.berkeley.edu")
    expect(email.to).to include("short@long.com")
    expect(email.subject).to eq("Teacher Form Submission")
    expect(email.body.encoded).to include("Here is the information that was submitted")
  end
end
