# frozen_string_literal: true

STATUS_FIELD = "What's your current status?"
EDUCATION_FIELD = "What's your education level target?"

Given(/a valid teacher exists/) do
  school = create(:school)
  create(:teacher, school:)
end

And(/^"(.*)" is not in the database$/) do |email|
  expect(Teacher.exists?(email:)).to be false
end

Given(/^I enter (?:my)? "(.*)" as "(.*)"$/) do |field_name, input|
  fill_in(field_name, with: input)
end

Given(/^I set my status as "(.*)"$/) do |input|
  select(input, from: STATUS_FIELD)
end

Given(/^I set my application status as "(.*)"$/) do |input|
  select(input, from: "application_status_select_value")
end

When(/^I select "(.*?)" from the languages dropdown$/) do |option|
  first(".selectize-input").click  # Click on the dropdown to open it
  find(".selectize-dropdown-content .option", text: option).click  # Click on the desired option
end

Given(/^I set my request reason as "(.*)"$/) do |input|
  fill_in("request_reason", with: input)
end

Given(/^I select "(.*)" from the skip email notification dropdown$/) do |input|
  select(input, from: "skip_email")
end

Given(/^I set my education level target as "(.*)"$/) do |input|
  select(input, from: EDUCATION_FIELD)
end

When(/^(?:|I )select "([^"]*)" from "([^"]*)" dropdown$/) do |value, readable_field|
  field_mappings = {
    "State" => "state_select"
  }
  field = field_mappings[readable_field] || readable_field
  select_box = find_field(field)
  options = select_box.all("option", text: value)
  if options.length > 1
    options.first.select_option
  else
    select(value, from: field)
  end
end

Then(/I see a confirmation "(.*)"/) do |string|
  page.should have_css ".alert", text: /#{string}/
end

Then(/The "(.*)" form is invalid/) do |id|
  page.evaluate_script("document.querySelector('#{id}').reportValidity()").should be false
end

Then(/^debug javascript$/) do
  page.driver.debugger
  1
end

Then(/^debug$/) do
  require "rubygems"; require "byebug"; byebug
  1 # intentionally force debugger context in this method
end

Then(/the "(.*)" of the user with email "(.*)" should be "(.*)"/) do |field, email, expected|
  expect(Teacher.find_by(email:)[field]).to eq(expected)
end

Then(/^I should find a teacher with email "([^"]*)" and school country "([^"]*)" in the database$/) do |email, country|
  teacher = Teacher.includes(:school).where(email:, 'schools.country': country).first
  expect(teacher).not_to be_nil, "No teacher found with email #{email} and country #{country}"
end

When(/^(?:|I )fill in the school name selectize box with "([^"]*)" and choose to add a new school$/) do |text|
  page.execute_script('$("#school_form").show()')
  # Necessary for the Admin School create page
  page.execute_script('$("#submit_button").show()')
  fill_in("School Name", with: text)
  # page.find(".label-required", text: "School Name").click
end

Then(/^"([^"]*)" click and fill option for "([^"]*)"(?: within "([^"]*)")?$/) do |value|
  find("#school_selectize").click.set(value)
end

Then(/^the new teacher form should not be submitted$/) do
  expect(current_path).to eq(new_teacher_path)
  expect(page).to have_content("Your Information")
  expect(page).to have_content("Create a new School")
end
