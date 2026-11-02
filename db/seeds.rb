# frozen_string_literal: true

# Production-safe seeds: email templates, UC Berkeley, and the core admins.
# For demo teachers and schools in development, run `bin/rails db:seed:sample_data`.
require_relative "seed_data"

SeedData.emails.each do |email_attrs|
  email_template = EmailTemplate.find_or_initialize_by({ title: email_attrs[:title] })
  email_template.update(email_attrs)
end

SeedData.create_schools
SeedData.upsert_teachers(SeedData.teachers)
SeedData.upsert_email_addresses(SeedData.email_addresses)
