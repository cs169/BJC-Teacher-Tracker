# frozen_string_literal: true

Given(/^I should see "(.*)" with "(.*)" in a table row$/) do |field_1, field_2|
  using_wait_time(10) do
    expect(page).to have_xpath(
      ".//tr[td[contains(., '#{field_1}')] and td[contains(., '#{field_2}')]]"
    )
  end
end
