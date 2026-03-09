# frozen_string_literal: true

require "cucumber/rspec/doubles"

# Returns a OAuth2 token associated with email "testteacher@berkeley.edu"
Given(/I have a teacher (.*) email/) do |login|
  service = LOGIN_SERVICE[login]
  OmniAuth.config.mock_auth[service] = OmniAuth::AuthHash.new({
    provider: service,
    uid: "123545",
    info: {
      name: "Joseph",
      first_name: "Joseph",
      last_name: "Mamoa",
      email: "testteacher@berkeley.edu",
      school: "UC Berkeley",
    },
    credentials: {
      token: "test_token",
      refresh_token: "test_refresh_token"
    }
  })
end

Given(/the following schools exist/) do |schools_table|
  schools_default = {
    name: "UC Berkeley - New",
    city: "Berkeley",
    state: "CA",
    website: "https://www.berkeley.edu",
    grade_level: "university",
    school_type: "public",
    tags: [],
    nces_id: 123456789100
  }
  schools_table.symbolic_hashes.each do |school|
    schools_default.each do |key, value|
      school[key] = value if school[key].nil?
    end
    School.create!(school)
  end
end

Given(/the following teachers exist/) do |teachers_table|
  teachers_default = {
    first_name: "Alonzo",
    last_name: "Church",
    snap: "",
    status: "Other - Please specify below.",
    education_level: 1,
    more_info: "default more_info",
    admin: false,
    personal_website: "https://example.com",
    application_status: "Not Reviewed",
    languages: ["English"],
    session_count: 1,
    last_session_at: DateTime.now,
    ip_history: [IPAddr.new("1.2.3.4")],
    # Note: primary email field does not exist in the new schema of the Teacher model
    # Include it in the seed data is to simulate the behavior of creating a new teacher,
    # because we need to use it to compared with the EmailAddress model,
    # to determine the existence of the teacher
    primary_email: "alonzo@snap.berkeley.edu"
  }

  teachers_table.symbolic_hashes.each do |teacher|
    teachers_default.each do |key, value|
      # Parse the 'languages' field as an array of strings using YAML.safe_load
      if key == :languages
        languages = if teacher[key].present? then YAML.safe_load(teacher[key]) else nil end
        teacher[key] = languages.presence || value
      elsif key == :last_session_at
        # conversion to DateTime object needed
        teacher[key] = if teacher[key].present? then DateTime.parse(teacher[key]) else value end
      elsif key == :session_count
        # type cast from string --> int needed
        teacher[key] = (teacher[key].presence || value).to_i
      elsif key == :ip_history
        # type cast from comma-separated list of ip addresses to array of IPAddr objects
        ip_addr_array = if teacher[key].present? then teacher[key].split(/\s*,\s*/).map { |ip_str| IPAddr.new(ip_str.strip) } else nil end
        teacher[key] = ip_addr_array.presence || value
      else
        # Handle other fields as usual
        teacher[key] = teacher[key].presence || value
      end
    end

    email = teacher.delete(:primary_email)

    school_name = teacher.delete(:school)
    school = School.find_by(name: school_name || "UC Berkeley")
    teacher[:school_id] = school.id
    teacher = Teacher.create!(teacher)
    EmailAddress.create!(email:, teacher:, primary: true)
    School.reset_counters(school.id, :teachers)
  end
end

Then(/the following entries should exist in the teachers database/) do |entries_table|
  entries_table.symbolic_hashes.each do |params|
    keys_to_exclude = [:school, :session_count, :last_session_at, :ip_history, :primary_email]
    # teacher should be present and school should be valid
    teacher = Teacher.find_by(params.except(*keys_to_exclude))
    expect(!teacher.blank?).to be true
    expect(!(School.find_by(name: params[:school]).blank?)).to be true
    if params[:session_count].present?
      expect(teacher.session_count).to eq(params[:session_count].to_i)
    end
    if params[:last_session_at].present?
      expect(teacher.last_session_at).to eq(DateTime.parse(params[:last_session_at]))
    end
    if params[:ip_history].present?
      ip_addr_array = params[:ip_history].split(/\s*,\s*/).map { |ip_str| IPAddr.new(ip_str.strip) }
      expect(teacher.ip_history.all? { |addr| ip_addr_array.include?(addr) }).to be true
    end
  end
end

Then(/the following entries should not exist in the teachers database/) do |entries_table|
  entries_table.symbolic_hashes.each do |teacher_params|
    teacher_params.except!(:school, :primary_email)
    # matches on all fields except school name
    expect(Teacher.find_by(teacher_params).blank?).to be true
  end
end

Then("the upload file field should be hidden") do
  expect(page).to have_selector("#upload_file_field", visible: :hidden)
end

Then("the upload file field should be visible") do
  expect(page).to have_selector("#upload_file_field", visible: :visible)
end

When("I attach the file with name {string} on the edit page") do |file_name|
  page.execute_script("$('teacher_more_files').click()")
  attach_file("teacher_more_files", Rails.root.join("spec/fixtures", file_name))
end

# Note: this is an admin-only action
When("I attach the file with name {string} on the show page") do |file_name|
  page.execute_script("$('label.btn.btn-primary.btn-purple.mr-2').click()"); # clicks the "Add a File" button
  # Execute JavaScript to make the file input field temporarily visible
  page.execute_script("$('#file-upload-field').css('display', 'block');")
  attach_file("file-upload-field", Rails.root.join("spec/fixtures", file_name))
  page.execute_script("$('#file-upload-field').css('display', 'none');")
end

When("I click the first file deletion button") do
  first('input[data-confirm="Are you sure you want to remove this file?"]').click
end
