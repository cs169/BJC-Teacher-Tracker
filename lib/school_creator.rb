# frozen_string_literal: true

module SchoolCreator
  def self.create_schools(number_of_schools, international: false)
    grade_levels = School.grade_levels.keys
    school_types = School.school_types.keys
    available_countries = ISO3166::Country.all

    school_ids = []
    number_of_schools.times do
      country = international ? available_countries.sample : ISO3166::Country["US"]
      state = country.states.keys.sample
      school = School.create!(
          name: Faker::Educator.university,
          city: Faker::Address.city,
          state:,
          country: country.alpha2,
          website: Faker::Internet.url,
          grade_level: grade_levels.sample,
          school_type: school_types.sample
        )
      school_ids.push(school.id)
    end
    school_ids
  end
end
