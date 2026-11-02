# frozen_string_literal: true

require "rails_helper"
require "csv_process"

RSpec.describe CsvProcess do
  fixtures :all

  let(:processor) { Class.new { include CsvProcess }.new }
  let(:school) { schools(:berkeley) }

  def base_row(overrides = {})
    { first_name: "Import", last_name: "Teacher", status: 0,
      personal_website: "https://example.com", school_id: school.id }.merge(overrides)
  end

  it "creates a new teacher with a primary EmailAddress record" do
    summary = processor.process_record([base_row(email: "new_import@example.com")])

    expect(summary[:success_count]).to eq(1)
    teacher = EmailAddress.find_by(email: "new_import@example.com")&.teacher
    expect(teacher).not_to be_nil
    expect(teacher.primary_email).to eq("new_import@example.com")
  end

  it "matches an existing teacher through their EmailAddress record" do
    existing = teachers(:long) # short@long.com

    summary = nil
    expect {
      summary = processor.process_record([base_row(email: "short@long.com", first_name: "Updated")])
    }.not_to change { Teacher.count }

    expect(summary[:success_count]).to eq(1)
    expect(existing.reload.first_name).to eq("Updated")
  end

  it "does not update an arbitrary snap-less teacher when the row has a blank snap" do
    bystander = teachers(:bob)
    bystander.update_column(:snap, nil)

    expect {
      processor.process_record([base_row(email: "brand_new@example.com", snap: nil)])
    }.to change { Teacher.count }.by(1)

    expect(bystander.reload.first_name).to eq("Bob")
  end

  it "counts a row with no email and no matching teacher as a failure instead of raising" do
    summary = nil
    expect {
      summary = processor.process_record([base_row(snap: "unknown_snap")])
    }.not_to change { Teacher.count }

    expect(summary[:success_count]).to eq(0)
    expect(summary[:fail_count]).to eq(1)
  end

  it "creates a school with an accurate teachers_count" do
    row = base_row(email: "school_import@example.com")
    row.delete(:school_id)
    row.merge!(school_name: "Imported High", school_city: "Oakland", school_state: "CA",
               school_country: "US", school_website: "imported.example.com",
               school_grade_level: 1, school_type: 0)

    summary = processor.process_record([row])

    expect(summary[:school_count]).to eq(1)
    expect(summary[:success_count]).to eq(1)
    new_school = School.find_by(name: "Imported High")
    expect(new_school.reload.teachers_count).to eq(1)
  end

  it "links the teacher to an existing school matched by name" do
    row = { first_name: "New", last_name: "Teacher", status: 0,
            personal_website: "https://example.com", email: "reuse@example.com",
            school_name: school.name }

    expect { processor.process_record([row]) }.not_to change(School, :count)

    expect(EmailAddress.find_by(email: "reuse@example.com").teacher.school).to eq(school)
  end

  it "defaults a new school's country to US when the row has none" do
    row = { first_name: "New", last_name: "Teacher", status: 0,
            personal_website: "https://example.com", email: "with.school@example.com",
            school_name: "Brand New High", school_city: "Oakland", school_state: "CA",
            school_website: "https://bnh.example.com", school_grade_level: 2, school_type: 0 }

    result = processor.process_record([row])

    expect(result[:school_count]).to eq(1)
    expect(result[:success_count]).to eq(1)
    expect(School.find_by(name: "Brand New High").country).to eq("US")
  end
end
