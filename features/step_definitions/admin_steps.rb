# frozen_string_literal: true

require "cucumber/rspec/doubles"

LOGIN_SERVICE = {
  Google: :google_oauth2,
  Microsoft: :microsoft_graph,
  Snap: :discourse,
  Clever: :clever
}.with_indifferent_access

# Under Puma/Selenium the mail is delivered on the app's request thread, and
# ActionMailer::Base.deliveries can lag the browser-visible redirect by a few
# hundred milliseconds. Poll for at least `min_count` deliveries so assertions
# don't race the mailer.
def wait_for_email(min_count: 1, timeout: Capybara.default_max_wait_time)
  Timeout.timeout(timeout) do
    sleep 0.05 until ActionMailer::Base.deliveries.length >= min_count
  end
  ActionMailer::Base.deliveries.last
rescue Timeout::Error
  raise "Expected >= #{min_count} email(s) in ActionMailer::Base.deliveries, got #{ActionMailer::Base.deliveries.length}"
end

# Returns a OAuth2 token associated with email "testadminuser@berkeley.edu"
Given(/I have an admin email/) do
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                       provider: "google_oauth2",
                                                                       uid: "123545",
                                                                       info: {
                                                                         name: "Admin User",
                                                                         first_name: "Admin",
                                                                         last_name: "User",
                                                                         email: "testadminuser@berkeley.edu",
                                                                         school: "UC Berkeley"
                                                                       }
                                                                     })
end

# Returns a OAuth2 token associated with email "randomemail@gmail.com"
Given(/I have a non-admin, unregistered (.*) email/) do |login|
  service = LOGIN_SERVICE[login]
  OmniAuth.config.mock_auth[service] = OmniAuth::AuthHash.new({
                                                                provider: service,
                                                                uid: "123545",
                                                                info: {
                                                                  name: "Random User",
                                                                  first_name: "Random",
                                                                  last_name: "User",
                                                                  email: "randomemail@berkeley.edu",
                                                                  school: "UC Berkeley",
                                                                }
                                                              })
end

# A wrapper around the omniauth link.
Then(/I can log in with (.*)/) do |login|
  service = LOGIN_SERVICE[login]
  allow(Teacher).to receive(:validate_auth).and_return(true)
  Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[service]
  page.find("button", text: /.*Sign in with #{login}/).click()
end

Then(/I cannot log in with Google/) do
  OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
  page.find("button", text: /.*Sign in with Google/).click()
end

Then(/I send a welcome email/) do
  last_email = wait_for_email
  last_email.to[0].should eq "testteacher@berkeley.edu"
  last_email.subject.should eq "Welcome to The Beauty and Joy of Computing!"
  last_email.body.encoded.should include "Thanks for teaching with BJC!"
end

Then(/I send a deny email/) do
  last_email = wait_for_email
  last_email.to[0].should eq "testteacher@berkeley.edu"
  last_email.subject.should eq "Deny Email"
  last_email.body.encoded.should include "sorry to inform you that your application has been rejected"
end

Then(/I send a request info email$/) do
  last_email = wait_for_email
  last_email.to[0].should eq "testteacher@berkeley.edu"
  last_email.subject.should eq "Request Info Email"
  last_email.body.encoded.should include "We kindly ask you to provide the following details to complete your application:"
end

Then(/I send a form submission email to both admin and teacher with email "(.*)"/) do |teacher_email|
  # this step definition assumes that the admin form submission email gets
  # sent first, as this is how it is implemented in the code
  wait_for_email(min_count: 2)
  admin_fs_email = ActionMailer::Base.deliveries[-2]
  teacher_fs_email = ActionMailer::Base.deliveries.last

  expect(admin_fs_email).not_to eq nil
  expect(teacher_fs_email).not_to eq nil
  admin_fs_email.subject.should eq "Form Submission"
  admin_fs_email.to[0].should eq "lmock@berkeley.edu"
  admin_fs_email.to[1].should eq "contact@bjc.berkeley.edu"
  admin_fs_email.body.encoded.should include "Here is the information that was submitted"
  teacher_fs_email.subject.should eq "Teacher Form Submission"
  teacher_fs_email.to[0].should eq teacher_email
  teacher_fs_email.body.encoded.should include "Here is the information that was submitted"
end

Then(/I attach the csv "([^"]*)"$/) do |path|
  Capybara.ignore_hidden_elements = false
  begin
    attach_file("file", File.expand_path(path))
  ensure
    Capybara.ignore_hidden_elements = true
  end
end

Then(/I send a request info email with content "(.*)"/) do |content|
  last_email = wait_for_email
  last_email.to[0].should eq "testteacher@berkeley.edu"
  last_email.subject.should eq "Request Info Email"
  last_email.body.encoded.should include "We kindly ask you to provide the following details to complete your application:"
  last_email.body.encoded.should include content
end

Then(/my most recent email did not have subject line "(.*)"/) do |subject|
  last_email = ActionMailer::Base.deliveries.last
  expect(last_email.subject).not_to eq subject
end

Then(/I should not have sent out any emails/) do
  last_email = ActionMailer::Base.deliveries.last
  last_email.should eq nil
end
