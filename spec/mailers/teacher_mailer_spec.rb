# frozen_string_literal: true

require "rails_helper"

describe TeacherMailer do
  fixtures :all

  before(:each) do
    Rails.application.load_seed
    ActionMailer::Base.deliveries.clear
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

  it "adds AWS SES tracking headers to teacher emails" do
    original_configuration_set = ENV["AWS_SES_CONFIGURATION_SET"]
    ENV["AWS_SES_CONFIGURATION_SET"] = "teacher-mail-events"

    begin
      teacher = teachers(:bob)
      email = TeacherMailer.welcome_email(teacher)

      expect(email["X-SES-CONFIGURATION-SET"].value).to eq("teacher-mail-events")
      expect(email["X-SES-MESSAGE-TAGS"].value).to include("app=bjc_teacher_tracker")
      expect(email["X-SES-MESSAGE-TAGS"].value).to include("teacher_id=#{teacher.id}")
      expect(email["X-SES-MESSAGE-TAGS"].value).to include("mailer_action=welcome_email")
    ensure
      ENV["AWS_SES_CONFIGURATION_SET"] = original_configuration_set
    end
  end

  it "filters suppressed recipients from teacher emails" do
    teacher = teachers(:barney)
    teacher.email_addresses.find_by(email: "bigpurpletrex@gmail.com").update_columns(
      suppressed_at: Time.current,
      suppression_reason: "hard_bounce"
    )

    email = TeacherMailer.welcome_email(teacher)

    expect(email.to).to include("barneydinosaur@gmail.com")
    expect(email.to).not_to include("bigpurpletrex@gmail.com")
  end

  it "does not deliver when every teacher recipient is suppressed" do
    teacher = teachers(:bob)
    teacher.email_addresses.update_all(suppressed_at: Time.current, suppression_reason: "hard_bounce")

    email = TeacherMailer.welcome_email(teacher)

    expect(email.to).to be_empty
    expect(email.perform_deliveries).to be(false)
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
    expect(email.body.encoded).to include("Short Long")
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
