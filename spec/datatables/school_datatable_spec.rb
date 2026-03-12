# frozen_string_literal: true

require "rails_helper"

RSpec.describe SchoolDatatable do
  fixtures :all

  let(:base_params) do
    ActionController::Parameters.new({
      draw: "1", start: "0", length: "10",
      search: { value: "", regex: "false" },
      order: { "0" => { column: "0", dir: "asc" } },
      columns: {
        "0" => { data: "name", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "1" => { data: "location", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "2" => { data: "country", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "3" => { data: "website", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "4" => { data: "teachers_count", searchable: "false", orderable: "true", search: { value: "", regex: "false" } },
        "5" => { data: "grade_level", searchable: "true", orderable: "true", search: { value: "", regex: "false" } },
        "6" => { data: "actions", searchable: "false", orderable: "false", search: { value: "", regex: "false" } }
      }
    })
  end

  it "returns all schools in recordsTotal" do
    datatable = SchoolDatatable.new(base_params)
    json = datatable.as_json
    expect(json[:recordsTotal]).to eq(School.count)
  end

  it "filters by search value" do
    params = ActionController::Parameters.new(
      base_params.to_unsafe_h.deep_merge("search" => { "value" => "nonexistent_xyz" })
    )
    datatable = SchoolDatatable.new(params)
    json = datatable.as_json
    expect(json[:recordsFiltered]).to eq(0)
  end

  it "returns data with expected keys" do
    datatable = SchoolDatatable.new(base_params)
    json = datatable.as_json
    if json[:data].any?
      record = json[:data].first
      expect(record).to have_key(:name)
      expect(record).to have_key(:location)
      expect(record).to have_key(:country)
      expect(record).to have_key(:website)
      expect(record).to have_key(:teachers_count)
      expect(record).to have_key(:grade_level)
      expect(record).to have_key(:actions)
    end
  end

  it "generates links in name and actions columns" do
    datatable = SchoolDatatable.new(base_params)
    json = datatable.as_json
    if json[:data].any?
      record = json[:data].first
      expect(record[:name]).to include("schools")
      expect(record[:actions]).to include("Edit")
    end
  end
end
