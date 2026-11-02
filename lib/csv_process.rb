# frozen_string_literal: true

module CsvProcess
  def process_record(teacher_hash_array)
    # Creates or updates a teacher / school for each hash element in teacher_hash_array.
    # For each entry in the csv:
    #   If invalid :school_id => create/update fails.
    #   If no :school_id => create the school data from hash if no school w/ same name exists
    #   If no :email and no existing teacher matched by :snap => the row fails
    #
    # Params:
    #   teacher_hash_array: Array of hash elements where each hash represents a row in the csv.
    #     Each hash contains the following keys: :first_name, :last_name, :education_level, :email,
    #       :more_info, :personal_website, :snap, :status, :school_id, :school_name, :school_city,
    #       :school_state, :school_country, :school_website, :school_grade_level, :school_type,
    #       :school_tags, :school_nces_id
    #
    # Returns:
    #   csv_import_summary_hash: A hash {
    #     success_count : (int),
    #     school_count : (int),
    #     failed_emails : Array of strings,
    #     failed_email_count : (int),
    #   }
    csv_import_summary_hash = { school_count: 0, success_count: 0, fail_count: 0, failed_emails: [] }

    teacher_hash_array.each do |row|
      school = School.find_by(id: row[:school_id])
      if !row[:school_id] # If there is no school id (different from having invalid school id)
        school = School.find_by(name: row[:school_name])
        if !school # Prevent creating the same school multiple times if same csv uploaded again
          school = School.new(school_params_from_row(row))
          if school.save
            row[:school_id] = school.id
            csv_import_summary_hash[:school_count] += 1
          else
            csv_import_summary_hash[:fail_count] += 1
            csv_import_summary_hash[:failed_emails].append(row[:email])
            next # don't try to create teacher
          end
        end
      elsif !school # row[:school_id] exists, but is invalid
        csv_import_summary_hash[:fail_count] += 1
        csv_import_summary_hash[:failed_emails].append(row[:email])
        next # don't try to create teacher
      end

      teacher = find_teacher_from_row(row)
      if teacher
        teacher.assign_attributes(teacher_update_params_from_row(row))
      elsif row[:email].present?
        teacher = Teacher.new(teacher_new_params_from_row(row))
        teacher.email_addresses.build(email: row[:email], primary: true)
      end

      if teacher&.save
        csv_import_summary_hash[:success_count] += 1
      else
        csv_import_summary_hash[:fail_count] += 1
        csv_import_summary_hash[:failed_emails].append(row[:email])
      end
    end

    csv_import_summary_hash
  end

  def add_flash_message(csv_import_summary_hash)
    # Assigns the flash messages for teacher csv upload
    #
    # Params:
    #   csv_import_summary_hash: A hash {
    #     success_count : (int),
    #     school_count : (int),
    #     failed_emails : Array of strings,
    #     failed_email_count : (int),
    #   }
    #
    # Returns: Nothing
    if csv_import_summary_hash[:success_count] > 0
      flash[:success] = "Successfully created/updated #{csv_import_summary_hash[:success_count]} teachers"
    end
    if csv_import_summary_hash[:school_count] > 0
      flash[:notice] = "#{csv_import_summary_hash[:school_count]} schools has been created"
    end
    if csv_import_summary_hash[:fail_count] > 0
      flash[:alert] = "#{csv_import_summary_hash[:fail_count]} teachers has failed with following emails:   "
      for email in csv_import_summary_hash[:failed_emails] do
        flash[:alert] += " [ #{email} ] "
      end
    end
  end

  private
  # Blank values must never be used for lookups: find_by(email: nil) or
  # find_by(snap: nil) matches the first teacher missing that value, so a
  # sparse CSV row would silently overwrite an unrelated record.
  def find_teacher_from_row(row)
    teacher = nil
    if row[:email].present?
      teacher = EmailAddress.find_by(email: row[:email].to_s.strip.downcase)&.teacher ||
        Teacher.find_by(email: row[:email])
    end
    teacher ||= Teacher.find_by(snap: row[:snap]) if row[:snap].present?
    teacher
  end

  def teacher_new_params_from_row(row)
    { first_name: row[:first_name],
      last_name: row[:last_name],
      education_level: row[:education_level],
      more_info: row[:more_info],
      personal_website: row[:personal_website],
      status: row[:status],
      school_id: row[:school_id],
      snap: row[:snap] }
  end

  def teacher_update_params_from_row(row)
    { first_name: row[:first_name],
      last_name: row[:last_name],
      education_level: row[:education_level],
      more_info: row[:more_info],
      personal_website: row[:personal_website],
      status: row[:status],
      school_id: row[:school_id] }
  end

  def school_params_from_row(row)
    { name: row[:school_name],
      city: row[:school_city],
      state: row[:school_state],
      country: row[:school_country],
      website: row[:school_website],
      grade_level: row[:school_grade_level],
      school_type: row[:school_type],
      tags: row[:school_tags],
      nces_id: row[:school_nces_id] }
  end
end
