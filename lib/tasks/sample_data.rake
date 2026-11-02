# frozen_string_literal: true

# Refuses to run in production unless ALLOW_SAMPLE_DATA=true is set, which
# should only ever be set on a staging app (Heroku staging apps also run
# with RAILS_ENV=production).
module SampleDataGuard
  def self.check!(task_name)
    return unless Rails.env.production?
    return if ENV["ALLOW_SAMPLE_DATA"] == "true"

    abort "ERROR: #{task_name} adds fake data and cannot run in production. " \
          "On a staging app, set ALLOW_SAMPLE_DATA=true to allow it."
  end
end

namespace :db do
  namespace :seed do
    desc "Load demo schools and teachers (runs db:seed first). Not for production."
    task sample_data: :environment do
      SampleDataGuard.check!("db:seed:sample_data")

      Rake::Task["db:seed"].invoke

      require Rails.root.join("db/seed_data")
      require Rails.root.join("db/sample_data")

      SampleData.create_schools
      SeedData.upsert_teachers(SampleData.teachers)
      SeedData.upsert_email_addresses(SampleData.email_addresses)

      puts "Sample data loaded: #{SampleData::SCHOOLS.size} schools, #{SampleData.teachers.size} teachers."
    end
  end
end
