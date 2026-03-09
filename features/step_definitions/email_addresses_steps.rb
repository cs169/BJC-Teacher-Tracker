# frozen_string_literal: true

require "cucumber/rspec/doubles"

Given(/the following emails exist/) do |emails_table|
  emails_table.symbolic_hashes.each do |email_hash|
    teacher = Teacher.find_by(first_name: email_hash[:first_name], last_name: email_hash[:last_name])
    raise "Teacher not found for email: #{email_hash[:email]}" unless teacher

    EmailAddress.create!(
      email: email_hash[:email],
      teacher:,
      primary: email_hash[:primary] == "true"
    )
  end
end

When(/^I click "Edit Personal Emails" to open the email modal$/) do
  click_button("Edit Personal Emails")
  expect(page).to have_css("#emailModal", visible: true)
end

When(/^I add "([^"]*)" to the email input$/) do |email|
  within("#emailModal") do
    find(".selectize-input").click
    find(".selectize-input input").set(email)
    find(".selectize-input input").native.send_keys(:return)
  end
end

When(/^I remove "([^"]*)" from the email input$/) do |email|
  within("#emailModal .selectize-control") do
    find(".item", text: email).find(".remove").click
  end
end

Then(/^I should see "([^"]*)" in the email tags$/) do |email|
  within("#emailModal .selectize-control") do
    expect(page).to have_css(".item", text: email)
  end
end

Then(/^I should not see "([^"]*)" in the email tags$/) do |email|
  within("#emailModal .selectize-control") do
    expect(page).not_to have_css(".item", text: email)
  end
end

When(/^I close the email modal$/) do
  within("#emailModal") do
    find(".modal-header").click
    sleep 0.2
    find("button.close span").click
  end
  expect(page).not_to have_css(".modal-backdrop", wait: 5)
end

When(/^I click the delete button for email "([^"]*)"$/) do |email|
  email_row = all(".email-list-item").find { |row| row.has_text?(email) }
  within(email_row) do
    find(".delete-email-btn").click
  end
end
