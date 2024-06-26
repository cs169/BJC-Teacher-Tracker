# frozen_string_literal: true

require_relative "seed_data"

SeedData.emails.each do |email_attrs|
  email_template = EmailTemplate.find_or_initialize_by({ title: email_attrs[:title] })
  email_template.update(email_attrs)
end

SeedData.create_schools

SeedData.teachers.each do |teacher_attr|
  email_address = EmailAddress.find_or_initialize_by(email: teacher_attr.delete(:email))

  if email_address.new_record?
    teacher = Teacher.create(teacher_attr)
    if teacher.persisted?
      email_address.teacher_id = teacher.id
      email_address.save
    else
      puts "Failed to create teacher. Errors: #{teacher.errors.full_messages.join(", ")}"
    end
  else
    teacher = Teacher.find_by(id: email_address.teacher_id)
    if !teacher&.update(teacher_attr)
      puts "Failed to update teacher. Errors: #{teacher.errors.full_messages.join(", ")}"
    end
  end
end

SeedData.email_addresses.each do |email_address|
  EmailAddress.find_or_create_by(email: email_address[:email]).update(email_address)
end
