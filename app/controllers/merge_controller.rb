# frozen_string_literal: true

class MergeController < ApplicationController
  before_action :require_admin

  def preview
    @from_teacher = Teacher.find(params[:from])
    @into_teacher = Teacher.find(params[:into])
    @result_teacher = merge_teachers(@from_teacher, @into_teacher)
  end

  def execute
    @from_teacher = Teacher.find(params[:from])
    @into_teacher = Teacher.find(params[:into])
    @merged_teacher = merge_teachers(@from_teacher, @into_teacher)

    merged_attributes = @merged_teacher.attributes.except("id")
    Teacher.transaction do
      merge_email_addresses(@from_teacher, @into_teacher)
      @from_teacher.destroy
      @into_teacher.update!(merged_attributes)
    end
    redirect_to teachers_path, notice: "Teachers merged successfully."
  end

  def school_preview
    @from_school = School.find(params[:from])
    @into_school = School.find(params[:into])
    @result_school = merge_schools(@from_school, @into_school)
  end

  def school_execute
    @from_school = School.find(params[:from])
    @into_school = School.find(params[:into])
    @merged_school = merge_schools(@from_school, @into_school)

    merged_attributes = @merged_school.attributes.except("id", "teachers_count")

    School.transaction do
      Teacher.where(school_id: @from_school.id).update_all(school_id: @into_school.id)
      @from_school.destroy
      @into_school.update_columns(merged_attributes)
    end

    School.reset_counters(@into_school.id, :teachers)
    redirect_to schools_path, notice: "Schools merged successfully."
  end

  private
  # TODO: Migrate to a library/service method
  # Returns a merged teacher without saving it to the database.
  # Rendered in the preview, and only saved to the DB in a call to merge.
  def merge_teachers(from_teacher, into_teacher)
    merged_attributes = {}
    into_teacher.attributes.each do |attr_name, attr_value|
      from_teacher_attr_value = from_teacher.attributes[attr_name]
      if attr_value.blank?
        merged_attributes[attr_name] = from_teacher_attr_value
      elsif from_teacher_attr_value.blank?
        merged_attributes[attr_name] = attr_value
      else
        case attr_name
        when "session_count"
          merged_attributes[attr_name] = attr_value + from_teacher_attr_value
        when "ip_history"
          merged_attributes[attr_name] = (attr_value + from_teacher_attr_value).uniq
        when "last_session_at"
          # The resulting last session time is the most recent one
          merged_attributes[attr_name] = attr_value > from_teacher_attr_value ? attr_value : from_teacher_attr_value
        when "created_at"
          # The resulting record creation time is the least recent one
          merged_attributes[attr_name] = attr_value < from_teacher_attr_value ? attr_value : from_teacher_attr_value
        else
          merged_attributes[attr_name] = attr_value
        end
      end
    end

    merged_teacher = Teacher.new(merged_attributes)
    merged_teacher.email_addresses = from_teacher.email_addresses + into_teacher.email_addresses
    merged_teacher
  end

  # TODO: Migrate to a library/service method
  def merge_schools(from_school, into_school)
    merged_attributes = {}
    into_school.attributes.each do |attr_name, attr_value|
      from_school_attr_value = from_school.attributes[attr_name]
      if attr_value.blank?
        merged_attributes[attr_name] = from_school_attr_value
      elsif from_school_attr_value.blank?
        merged_attributes[attr_name] = attr_value
      else
        case attr_name
        when "tags"
          merged_attributes[attr_name] = (attr_value + from_school_attr_value).uniq
        when "teachers_count"
          merged_attributes[attr_name] = attr_value + from_school_attr_value
        when "created_at"
          merged_attributes[attr_name] = [attr_value, from_school_attr_value].min
        else
          merged_attributes[attr_name] = attr_value
        end
      end
    end
    School.new(merged_attributes)
  end

  # Handle merging EmailAddress records, so they all belong to the saved record.
  # This method is designed to be inside a transaction for safety.
  def merge_email_addresses(from_teacher, into_teacher)
    existing_emails = into_teacher.email_addresses

    # Ensure there is only one primary email if both have a primary.
    if into_teacher.primary_email.present?
      from_teacher.email_addresses.update_all(primary: false)
    end

    from_teacher.email_addresses.each do |email_address|
      if existing_emails.select(:email).include?(email_address.email.strip.downcase)
        puts "[WARN]: Merge Teacher #{from_teacher.id} into #{into_teacher.id} found duplicate email: '#{email_address.email}'"
        next
      end
      email_address.update!(teacher: into_teacher)
    end
  end
end
