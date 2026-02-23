# frozen_string_literal: true

module TeacherCreator
  def self.create_teachers(number_of_teachers, school_ids)
    statuses = Teacher.statuses.keys
    education_levels = Teacher.education_levels.keys
    teachers = []

    number_of_teachers.times do
      teacher = Teacher.create!(
          first_name: Faker::Name.first_name,
          last_name: Faker::Name.last_name,
          snap: Faker::Internet.username,
          school_id: school_ids.sample,
          personal_website: Faker::Internet.domain_name,
          status: statuses.sample,
          more_info: Faker::Lorem.sentence(word_count: 20),
          education_level: education_levels.sample,
          languages: Teacher::WORLD_LANGUAGES.sample(rand(1..3))
        )
      if teacher.persisted?
        # Generate an email using the first_name and last_name from the teacher instance
        email = Faker::Internet.email(name: "#{teacher.first_name} #{teacher.last_name}", separators: ["."])
        EmailAddress.create!(
            teacher_id: teacher.id,
            email:,
            primary: true
          )
      end
      teachers.push(teacher)
    end
    teachers
  end
end
