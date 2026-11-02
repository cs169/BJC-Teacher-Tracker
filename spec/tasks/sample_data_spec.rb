# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "seed data" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  describe "db:seed" do
    it "does not create demo teachers" do
      Rails.application.load_seed

      expect(EmailAddress.where("email LIKE ?", "%.example").count).to eq(0)
      expect(Teacher.find_by(first_name: "Priya", last_name: "Ramirez")).to be_nil
    end

    it "never attaches seed addresses to a teacher found only by first name" do
      impostor = Teacher.create!(first_name: "Michael", last_name: "Impostor", status: 0,
                                 personal_website: "https://example.com", school: School.first)
      impostor.email_addresses.create!(email: "impostor@example.com", primary: true)

      Rails.application.load_seed

      expect(impostor.reload.email_addresses.pluck(:email)).to eq(["impostor@example.com"])
    end
  end

  describe "db:seed:sample_data" do
    let(:task) { Rake::Task["db:seed:sample_data"] }

    after do
      task.reenable
      Rake::Task["db:seed"].reenable
    end

    it "refuses to run in production" do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect { task.invoke }.to raise_error(SystemExit)
    end

    it "loads demo teachers using only reserved example domains" do
      expect { task.invoke }.to output(/Sample data loaded/).to_stdout

      sample = EmailAddress.where("email LIKE ? OR email LIKE ?", "%.example", "%@example.com")
      expect(sample.count).to be >= 12
      expect(Teacher.find_by(first_name: "Sofia", last_name: "Chen")).to be_present
    end
  end

  describe "db:staging_seed" do
    it "refuses to run in production" do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect { Rake::Task["db:staging_seed"].invoke("/tmp/none.csv") }.to raise_error(SystemExit)
    ensure
      Rake::Task["db:staging_seed"].reenable
    end
  end
end
