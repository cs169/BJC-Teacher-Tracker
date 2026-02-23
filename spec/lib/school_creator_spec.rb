# frozen_string_literal: true

require "rails_helper"
require "./lib/school_creator"

RSpec.describe SchoolCreator do
  describe "#create_schools" do
    let(:valid_states) { School::VALID_STATES }
    let(:grade_levels) { ["elementary", "middle_school", "high_school"] }
    let(:school_types) { ["public", "private"] }

    before do
      allow(School).to receive_message_chain(:grade_levels, :keys).and_return(grade_levels)
      allow(School).to receive_message_chain(:school_types, :keys).and_return(school_types)
    end

    it "creates the specified number of US schools" do
      schools = SchoolCreator.create_schools(5)
      expect(schools.length).to eq(5)
    end

    it "creates schools with appropriate attributes for US schools" do
      SchoolCreator.create_schools(1)
      school = School.last

      expect(school.country).to eq("US")
      expect(valid_states).to include(school.state)
      expect(grade_levels).to include(school.grade_level)
      expect(school_types).to include(school.school_type)
    end

    it "creates schools with no state for international schools" do
      SchoolCreator.create_schools(1, international: true)
      school = School.last

      expect(school.state).to be_nil
    end
  end
end
