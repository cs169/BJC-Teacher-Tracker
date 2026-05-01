# frozen_string_literal: true

When(/^I fill in the teachers table search with "([^"]*)"$/) do |value|
  first(".js-teachersTable").ancestor(".dataTables_wrapper").find(".dataTables_filter input").set(value)
end

Given(/^I should see "(.*)" with "(.*)" in a table row$/) do |field_1, field_2|
  both = false
  page.find_all("tr").each do |table_row|
    field_1_present = false
    field_2_present = false
    table_row.find_all("td").each do |table_entry|
      if table_entry.text == field_1
        field_1_present = true
      elsif table_entry.text == field_2
        field_2_present = true
      end
    end
    if field_1_present && field_2_present
      both = true
      break
    end
  end
  if not both
    raise "No row contained both '#{field_1}' and '#{field_2}'"
  end
end
