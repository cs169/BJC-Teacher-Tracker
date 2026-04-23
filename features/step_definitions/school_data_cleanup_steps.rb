
# frozen_string_literal: true

Before do
  @schools = {}
end

Given(/^a school "([^"]*)" exists with no country and state "([^"]*)"$/) do |name, state|
  school = FactoryBot.create(:school, name:, state:)

  school.update_column(:country, nil)

  @schools[name] = school
end

Given(/^a school "([^"]*)" exists with no country and website "([^"]*)"$/) do |name, website|
  school = FactoryBot.create(:school, name:, website:)

  school.update_column(:country, nil)
  school.update_column(:state, nil)
  school.update_column(:lat, nil)
  school.update_column(:lng, nil)

  @schools[name] = school
end

Given(/^a school "([^"]*)" exists with country "([^"]*)"$/) do |name, country|
  school = FactoryBot.create(:school, name:, country:)
  @schools[name] = school
end


Given(/^a school "([^"]*)" exists with grade level "([^"]*)"$/) do |name, grade_level|
  school = FactoryBot.create(:school, name:, grade_level: grade_level.to_sym)
  @schools[name] = school
end

Given(/^the school "([^"]*)" has (\d+) teachers with education level "([^"]*)"$/) do |name, count, level|
  school = @schools[name] || School.find_by!(name:)

  count.to_i.times do |i|
    FactoryBot.create(
      :teacher,
      school:,
      education_level: level.to_sym,
      snap: "#{name.parameterize}-teacher-#{i}"
    )
  end
end


When(/^I run the rake task "([^"]*)"$/) do |task_name|
  Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)

  unless Rake::Task.task_defined?(task_name)
    Rake.application.rake_require(
      "tasks/school_data_cleanup",
      [Rails.root.join("lib").to_s]
    )
  end

  ENV["APPLY"] = "true"

  Rake::Task[task_name].invoke

  Rake::Task[task_name].reenable

  ENV.delete("APPLY")
end


Then(/^the school "([^"]*)" should have country "([^"]*)"$/) do |name, expected_country|
  school = @schools[name] || School.find_by!(name:)

  school.reload

  expect(school.country).to eq(expected_country),
    "Expected school '#{name}' to have country '#{expected_country}', " \
    "but got '#{school.country}'"
end

Then(/^the school "([^"]*)" should have no country$/) do |name|
  school = @schools[name] || School.find_by!(name:)
  school.reload

  expect(school.country).to be_nil,
    "Expected school '#{name}' to have no country (nil), " \
    "but got '#{school.country}'"
end

Then(/^the school "([^"]*)" should have grade level "([^"]*)"$/) do |name, expected_level|
  school = @schools[name] || School.find_by!(name:)
  school.reload

  expect(school.grade_level).to eq(expected_level),
    "Expected school '#{name}' to have grade_level '#{expected_level}', " \
    "but got '#{school.grade_level}'"
end
