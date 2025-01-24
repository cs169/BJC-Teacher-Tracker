# frozen_string_literal: true

require "school_creator"
require "teacher_creator"

namespace :db do
  desc "Populate the database with fake teacher data"
  task populate_teachers: :environment do
    number_of_US_schools = 5
    number_of_international_schools = 5
    school_ids = []

    # Create US schools
    school_ids << SchoolCreator.create_schools(number_of_US_schools)

    # Create International schools
    school_ids << SchoolCreator.create_schools(number_of_international_schools, international: true)

    if school_ids.empty?
      puts "No schools available to assign. Please create schools first."
      exit
    end

    number_of_teachers = 30
    TeacherCreator.create_teachers(number_of_teachers, school_ids)

    puts "#{number_of_US_schools} US schools created. \n#{number_of_US_schools} international schools created. \n#{number_of_teachers} teachers created."
  end
end
