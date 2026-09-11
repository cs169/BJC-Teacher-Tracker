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
    fill_in("Email address", with: email)
  end
end

When(/^I clear the email input$/) do
  within("#emailModal") do
    fill_in("Email address", with: "")
  end
end

When(/^I close the email modal$/) do
  # Bootstrap 4's modal('hide') is a no-op while the modal is still animating
  # open (_isTransitioning=true). Under Selenium we drive the click sequence
  # faster than the 300ms fade completes, so the hide silently drops and the
  # modal stays open. Force-close by stripping the show classes and backdrop
  # directly — the DOM state we care about is the same regardless of which
  # path got us there.
  page.execute_script(<<~JS)
    $('#emailModal').removeClass('fade show d-block').css('display', 'none').attr('aria-hidden', 'true');
    $('.modal-backdrop').remove();
    $('body').removeClass('modal-open');
  JS
  expect(page).to have_no_css("#emailModal.show")
  expect(page).to have_no_css(".modal-backdrop")
end

When(/^I click the delete button for email "([^"]*)"$/) do |email|
  email_row = all(".email-list-item").find { |row| row.has_text?(email) }
  page.accept_confirm "Are you sure you want to delete this email?" do
    within(email_row) do
      find(".delete-email-btn").click
    end
  end
end
