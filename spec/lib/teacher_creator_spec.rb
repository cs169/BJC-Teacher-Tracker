# frozen_string_literal: true

require "rails_helper"
require "./lib/teacher_creator"

RSpec.describe TeacherCreator do
    describe "#create_teachers" do
      let(:school_ids) { [] }
      let(:statuses) { ["csp_teacher", "non_csp_teacher", "mixed_class"] }
      let(:education_levels) { ["middle_school", "high_school", "college"] }
      let(:languages) { ["English", "Romanian", "German"] }
      let(:valid_states) { ["CA", "NY", "TX"] }

      before do
        # Create schools directly and push their IDs to the school_ids array
        3.times do |i|
          school = School.create!(
            name: "School #{i}",
            city: Faker::Address.city,
            country: "US",
            website: Faker::Internet.url,
            state: valid_states.sample
          )
          school_ids << school.id
        end

        allow(Teacher).to receive_message_chain(:statuses, :keys).and_return(statuses)
        allow(Teacher).to receive_message_chain(:education_levels, :keys).and_return(education_levels)
        Teacher::WORLD_LANGUAGES = languages
      end

      it "creates the specified number of teachers" do
        expect {
          TeacherCreator.create_teachers(10, school_ids)
        }.to change(Teacher, :count).by(10)
      end

      it "assigns valid school_ids to each teacher" do
        TeacherCreator.create_teachers(5, school_ids)
        Teacher.last(5).each do |teacher|
          expect(school_ids).to include(teacher.school_id)
        end
      end
    end
  end
