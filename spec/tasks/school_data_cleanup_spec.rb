
# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "school_data_cleanup rake tasks" do
  before(:all) do
    Rake.application = Rake::Application.new

    Rake::Task.define_task(:environment)

    Rake.application.rake_require(
      "tasks/school_data_cleanup",
      [Rails.root.join("lib").to_s]
    )
  end

  describe "schools:fix_countries" do
    let(:task) { Rake::Task["schools:fix_countries"] }

    after(:each) { task.reenable }

    around(:each) do |example|
      original = ENV["APPLY"]
      ENV["APPLY"] = "true"
      example.run
    ensure
      ENV["APPLY"] = original
    end

    it "assigns 'US' to a school with nil country and a valid US state" do
      school = create(:school, state: "CA")

      school.update_column(:country, nil)

      expect(school.reload.country).to be_nil

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.country).to eq("US")
    end

    it "infers country from a non-generic website TLD" do
      school = create(:school, website: "https://www.scoala.ro")

      school.update_column(:country, nil)
      school.update_column(:state, nil)

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.country).to eq("RO")
    end

    it "does not modify a school that already has a valid country" do
      school = create(:school, country: "US", state: "NY")

      school.reload
      original_updated_at = school.updated_at

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.country).to eq("US")
      expect(school.updated_at).to eq(original_updated_at)
    end

    it "leaves country nil when no heuristic can determine it" do
      school = create(:school, website: "https://example.com")

      school.update_column(:country, nil)
      school.update_column(:state, nil)
      school.update_column(:lat, nil)
      school.update_column(:lng, nil)

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.country).to be_nil
    end

    it "does not write changes in dry-run mode" do
      school = create(:school, state: "CA")
      school.update_column(:country, nil)

      ENV["APPLY"] = "false"

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.country).to be_nil
    end
  end

  describe "schools:fix_grade_levels" do
    let(:task) { Rake::Task["schools:fix_grade_levels"] }

    after(:each) { task.reenable }

    around(:each) do |example|
      original = ENV["APPLY"]
      ENV["APPLY"] = "true"
      example.run
    ensure
      ENV["APPLY"] = original
    end

    it "fixes grade_level when both name and teacher heuristics agree (high confidence)" do
      school = create(:school, name: "Springfield High School", grade_level: :elementary)

      create(:teacher, school:, education_level: :high_school,
                       snap: "teacher_hs_1")
      create(:teacher, school:, education_level: :high_school,
                       snap: "teacher_hs_2")

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.grade_level).to eq("high_school")
    end

    it "does not auto-fix when only the name heuristic fires (low confidence)" do
      school = create(:school, name: "City Elementary", grade_level: :high_school)

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.grade_level).to eq("high_school")
    end

    it "does not modify a school whose grade_level is already correct" do
      school = create(:school, name: "Oak High School", grade_level: :high_school)

      school.reload
      original_updated_at = school.updated_at

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.grade_level).to eq("high_school")
      expect(school.updated_at).to eq(original_updated_at)
    end

    it "does not auto-fix when only teacher heuristic fires (low confidence)" do
      school = create(:school, name: "Learning Academy", grade_level: :elementary)

      create(:teacher, school:, education_level: :high_school,
                       snap: "hs_teacher_1")
      create(:teacher, school:, education_level: :high_school,
                       snap: "hs_teacher_2")

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.grade_level).to eq("elementary")
    end

    it "does not write changes in dry-run mode" do
      school = create(:school, name: "Springfield High School", grade_level: :elementary)

      create(:teacher, school:, education_level: :high_school,
                       snap: "dry_run_teacher_1")
      create(:teacher, school:, education_level: :high_school,
                       snap: "dry_run_teacher_2")

      ENV["APPLY"] = "false"

      expect { task.invoke }.to output.to_stdout

      school.reload
      expect(school.grade_level).to eq("elementary")
    end
  end
end
