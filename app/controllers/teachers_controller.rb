# frozen_string_literal: true

# TODO: These belong in a separate file.
require "smarter_csv"
require "csv_process"
require "activerecord-import"

class TeachersController < ApplicationController
  include SchoolParams
  include CsvProcess

  before_action :load_pages, only: [:new, :create, :edit, :update]
  before_action :load_teacher, except: [:new, :index, :create, :import, :search]
  before_action :sanitize_params, only: [:new, :create, :edit, :update]
  before_action :require_login, except: [:new, :create]
  before_action :require_admin, only: [:validate, :deny, :destroy, :index, :show, :search]
  before_action :require_edit_permission, only: [:edit, :update, :resend_welcome_email]

  rescue_from ActiveRecord::RecordNotUnique, with: :deny_access

  # Pages which are publicly visible.
  layout "page_with_sidebar", only: [:new, :edit, :update]

  def index
    respond_to do |format|
      format.html {
        @all_teachers = Teacher.eager_load(:email_addresses, :school).where(admin: false)
        @admins = Teacher.eager_load(:email_addresses, :school).where(admin: true)
      }
      format.csv { send_data Teacher.csv_export, filename: "teachers-#{Date.today}.csv" }
    end
  end

  def show
    @all_teachers_except_current = Teacher.preload(:email_addresses, :school).where.not(id: @teacher.id)
    @school = @teacher.school
    @status = is_admin? ? "Admin" : "Teacher"
  end

  def new
    ordered_schools
    @teacher = Teacher.new
    @teacher.school = School.new
    @school = @teacher.school # maybe delegate this
    @readonly = false
    if omniauth_data.present?
      email_data = { email: omniauth_data.delete("email"), primary: true }
      @teacher.assign_attributes(omniauth_data)
      @teacher.email_addresses.build(email_data)
    end
  end

  # TODO: This needs to be re-written.
  # If you are logged in and not an admin, this should fail.
  def create
    if existing_teacher
      return
    end

    load_school
    if @school.new_record?
      return unless params[:school]
      @school = School.new(school_params)
      unless @school.save
        flash[:alert] = "An error occurred: #{@school.errors.full_messages.join(', ')}"
        render "new" && return
      end
    end

    @teacher = Teacher.new(teacher_params)
    @teacher.email_addresses.build(email: params[:email][:primary], primary: true)

    @teacher.try_append_ip(request.remote_ip)
    @teacher.session_count += 1
    @teacher.school = @school
    if @teacher.save
      @teacher.not_reviewed!
      flash[:success] = "Thanks for signing up for BJC, #{@teacher.first_name}! You'll hear from us shortly. Your email address is: #{@teacher.primary_email}."
      TeacherMailer.form_submission(@teacher).deliver_now
      TeacherMailer.teacher_form_submission(@teacher).deliver_now
      redirect_to root_path
    else
      flash.now[:alert] = "An error occurred: #{@teacher.errors.full_messages.join(', ')}"
      render "new"
    end
  end

  def edit
    ordered_schools
    @school = @teacher.school
    @status = is_admin? ? "Admin" : "Teacher"
    @readonly = !is_admin?
  end

  def remove_file
    file_attachment = @teacher.files.find(params[:file_id])
    file_attachment.purge
    flash[:notice] = "File was successfully removed"
    redirect_back fallback_location: teacher_path(@teacher)
  end

  def upload_file
    @teacher.files.attach(params[:file])
    redirect_back fallback_location: teacher_path(@teacher), notice: "File was successfully uploaded"
  end

  def update
    load_school
    ordered_schools

    primary_email = params.dig(:email, :primary)

    @teacher.assign_attributes(teacher_params)

    update_primary_email(primary_email)
    if teacher_params[:school_id].present?
      @teacher.school = @school
    else
      @school.update(school_params) if school_params
      unless @school.save
        flash.now[:alert] = "An error occurred: #{@school.errors.full_messages.join(', ')}"
        render "edit" && return
      end
      @teacher.school = @school
    end

    valid_school = update_school_through_teacher
    if !valid_school
      return
    end

    attach_new_files_if_any
    send_email_if_application_status_changed_and_email_resend_enabled

    if fail_to_update
      return
    end

    if !@teacher.validated? && !current_user.admin?
      TeacherMailer.form_submission(@teacher).deliver_now
      TeacherMailer.teacher_form_submission(@teacher).deliver_now
    end

    if is_admin?
      redirect_to edit_teacher_path(params[:id]), notice: "Saved #{@teacher.full_name}"
    else
      @teacher.try_append_ip(request.remote_ip)
      redirect_to edit_teacher_path(params[:id]), notice: "Successfully updated your information"
    end
  end

  def send_email_if_application_status_changed_and_email_resend_enabled
    if @teacher.application_status_changed? && params[:skip_email] == "No"
      case @teacher.application_status
      when "validated"
        TeacherMailer.welcome_email(@teacher).deliver_now
      when "denied"
        TeacherMailer.deny_email(@teacher, params[:request_reason]).deliver_now
      when "info_needed"
        TeacherMailer.request_info_email(@teacher, params[:request_reason]).deliver_now
      end
    end
  end

  def request_info
    @teacher.info_needed!
    if !params[:skip_email].present?
      TeacherMailer.request_info_email(@teacher, params[:request_reason]).deliver_now
    end
    redirect_to root_path
  end

  def validate
    @teacher.validated!
    TeacherMailer.welcome_email(@teacher).deliver_now
    redirect_to root_path
  end

  def deny
    @teacher.denied!
    if !params[:skip_email].present?
      TeacherMailer.deny_email(@teacher, params[:denial_reason]).deliver_now
    end
    redirect_to root_path
  end

  def destroy
    @teacher.destroy!
    flash[:info] = "Deleted #{@teacher.full_name} successfully."
    redirect_to teachers_path
  end

  def resend_welcome_email
    if @teacher.validated? || @is_admin
      flash[:success] = "Welcome email resent successfully!"
      TeacherMailer.welcome_email(@teacher).deliver_now
    else
      flash[:alert] = "Error resending welcome email. Please ensure that your account has been validated by an administrator."
    end
    redirect_back(fallback_location: dashboard_path)
  end

  def import
    csv_file = params[:file]
    teacher_hash_array = SmarterCSV.process(csv_file)
    csv_import_summary_hash = process_record(teacher_hash_array)
    add_flash_message(csv_import_summary_hash)
    redirect_to teachers_path
  end

  private
  def load_teacher
    @teachers = Teacher.all
    @teacher ||= Teacher.find(params[:id])
  end

  def deny_access
    redirect_to new_teacher_path, alert: "Email address or Snap username already in use. Please use a different email or Snap username."
  end

  def existing_teacher
    # Find by email, but allow updating other info.
    @teacher = EmailAddress.find_by(email: params.dig(:email, :primary))&.teacher
    if @teacher && defined?(current_user.id) && (current_user.id == @teacher.id)
      params[:id] = current_user.id
      update
      return true
    elsif @teacher
      redirect_to login_path, notice: "You already have signed up with '#{@teacher.email}'. Please log in."
      return true
    end
    false
  end

  def update_school_through_teacher
    if !teacher_params[:school_id].present?
      @school.update(school_params) if school_params
      unless @school.save
        flash[:alert] = "An error occurred: #{@school.errors.full_messages.join(', ')}"
        render "new"
        return false
      end
    end
    @teacher.school = @school
    true
  end

  def fail_to_update
    if @teacher.denied? && !is_admin?
      redirect_to root_path, alert: "Failed to update your information. You have already been denied. If you have questions, please email contact@bjc.berkeley.edu."
      return true
    elsif (@teacher.email_changed_flag || @teacher.snap_changed?) && !is_admin?
      flash.now[:alert] = "Failed to update your information. If you want to change your email or Snap! username, please email contact@bjc.berkeley.edu."
      render "edit"
      return true
    elsif !@teacher.save
      flash.now[:alert] = "Failed to update data. #{@teacher.errors.full_messages.to_sentence}"
      render "edit"
      return true
    end
    false
  end

  def load_school
    if teacher_params[:school_id].present?
      @school ||= School.find(teacher_params[:school_id])
    end
    @school ||= School.find_or_create_by(**unique_school_params)
  end

  def attach_new_files_if_any
    if params.dig(:teacher, :more_files).present?
      params[:teacher][:more_files].each do |file|
        @teacher.files.attach(file)
      end
    end
  end

  def teacher_params
    teacher_attributes = [:first_name, :last_name, :school, :status, :snap,
                          :more_info, :verification_notes, :personal_website, :education_level, :school_id, languages: [], files: [],
                        more_files: []]
    admin_attributes = [:application_status, :request_reason, :skip_email]
    teacher_attributes.push(*admin_attributes) if is_admin?

    params.require(:teacher).permit(*teacher_attributes)
  end

  def omniauth_data
    @omniauth_data ||= session[:auth_data]&.slice("first_name", "last_name", "email")
  end

  def ordered_schools
    if params[:id].present?
      load_teacher
      @ordered_schools ||= [@teacher.school] +
        School.all.order(:name).reject { |s| s.id == @teacher.school_id }
    else
      @ordered_schools ||= School.all.order(:name)
    end
  end

  def sanitize_params
    teacher = params[:teacher]
    if teacher && teacher[:status]
      teacher[:status] = teacher[:status].to_i
    end
    if teacher && teacher[:education_level]
      teacher[:education_level] = teacher[:education_level].to_i
    end

    school = params[:school]
    if school && school[:grade_level]
      school[:grade_level] = school[:grade_level].to_i
    end
    if school && school[:school_type]
      school[:school_type] = school[:school_type].to_i
    end
  end

  def load_pages
    @pages ||= Page.where(viewer_permissions: Page.viewable_pages(current_user))
  end

  def update_primary_email(primary_email)
    return unless primary_email.present?

    # First, ensure the current primary email is marked as not primary if it's not the same as the new one
    @teacher.email_addresses.find_by(primary: true)&.update(primary: false)

    primary_email_record = @teacher.email_addresses.find_or_initialize_by(email: primary_email)
    primary_email_record.primary = true

    primary_email_record.save if primary_email_record.changed?
  end
end
