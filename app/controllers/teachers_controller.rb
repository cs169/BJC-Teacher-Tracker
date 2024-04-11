# frozen_string_literal: true

# TODO: These belong in a separate file.
require "smarter_csv"
require "csv_process"
require "activerecord-import"

class TeachersController < ApplicationController
  include CsvProcess

  before_action :load_pages, only: [:new, :create, :edit, :update]
  before_action :load_teacher, except: [:new, :index, :create, :import]
  before_action :sanitize_params, only: [:new, :create, :edit, :update]
  before_action :require_login, except: [:new, :create]
  before_action :require_admin, only: [:validate, :deny, :destroy, :index, :show]
  before_action :require_edit_permission, only: [:edit, :update, :resend_welcome_email]

  rescue_from ActiveRecord::RecordNotUnique, with: :deny_access

  # Pages which are publicly visible.
  layout "page_with_sidebar", only: [:new, :edit, :update]

  def index
    respond_to do |format|
      format.html {
        @all_teachers = Teacher.where(admin: false)
        @admins = Teacher.where(admin: true)
      }
      format.csv { send_data Teacher.csv_export, filename: "teachers-#{Date.today}.csv" }
    end
  end

  def show
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
      @teacher.assign_attributes(omniauth_data)
    end
  end

  # TODO: This needs to be re-written.
  # If you are logged in and not an admin, this should fail.
  def create
    if existing_teacher
      return
    end

    valid_school = find_or_create_school
    if !valid_school
      return
    end

    @teacher = Teacher.new(teacher_params)
    @teacher.try_append_ip(request.remote_ip)
    @teacher.session_count += 1
    @teacher.school = @school
    if @teacher.save
      @teacher.not_reviewed!
      flash[:success] = "Thanks for signing up for BJC, #{@teacher.first_name}! You'll hear from us shortly. Your email address is: #{@teacher.email}."
      TeacherMailer.form_submission(@teacher).deliver_now
      TeacherMailer.teacher_form_submission(@teacher).deliver_now
      redirect_to root_path
    else
      redirect_to new_teacher_path, alert: "An error occurred: #{@teacher.errors.full_messages.join(', ')}"
    end
  end

  def edit
    ordered_schools
    @school = @teacher.school
    @status = is_admin? ? "Admin" : "Teacher"
    @readonly = !is_admin?
  end

  def update
    load_school
    ordered_schools
    @teacher.assign_attributes(teacher_params)

    valid_school = update_school_through_teacher
    if !valid_school
      return
    end

    send_email_if_application_status_changed_and_email_resend_enabled

    if fail_to_update
      return
    end

    if !@teacher.validated? && !current_user.admin?
      TeacherMailer.form_submission(@teacher).deliver_now
      TeacherMailer.teacher_form_submission(@teacher).deliver_now
    end

    if is_admin?
      redirect_to teachers_path, notice: "Saved #{@teacher.full_name}"
    else
      @teacher.try_append_ip(request.remote_ip)
      redirect_to edit_teacher_path(current_user.id), notice: "Successfully updated your information"
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
    @teacher ||= Teacher.find(params[:id])
  end

  def deny_access
    redirect_to new_teacher_path, alert: "Email address or Snap username already in use. Please use a different email or Snap username."
  end

  def existing_teacher
    # Find by email, but allow updating other info.
    @teacher = Teacher.find_by(email: teacher_params[:email])
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

  def find_or_create_school
    load_school
    if @school.new_record?
      @school = School.new(school_params)
      unless @school.save
        flash[:alert] = "An error occurred! #{@school.errors.full_messages.join(', ')}"
        render "new"
        return false
      end
    end
    true
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
    failed = false
    if @teacher.denied? && !is_admin?
      redirect_to root_path, alert: "Failed to update your information. You have already been denied. If you have questions, please email contact@bjc.berkeley.edu."
      failed = true
    elsif (@teacher.email_changed? || @teacher.snap_changed?) && !is_admin?
      flash.now[:alert] = "Failed to update your information. If you want to change your email or Snap! username, please email contact@bjc.berkeley.edu."
      render "edit"
      failed = true
    elsif !@teacher.save
      flash.now[:alert] = "Failed to update data. #{@teacher.errors.full_messages.to_sentence}"
      render "edit"
      failed = true
    end
    failed
  end

  def load_school
    if teacher_params[:school_id].present?
      @school ||= School.find(teacher_params[:school_id])
    end
    @school ||= School.find_or_create_by(name: school_params[:name], city: school_params[:city], country: school_params[:country], state: school_params[:state])
  end

  def teacher_params
    teacher_attributes = [:first_name, :last_name, :school, :email, :status, :snap,
      :more_info, :personal_website, :education_level, :school_id]
    if is_admin?
      teacher_attributes << [:personal_email, :application_status,
      :request_reason, :skip_email]
    end
    params.require(:teacher).permit(*teacher_attributes, languages: [])
  end

  def school_params
    return unless params[:school]
    params.require(:school).permit(:name, :country, :city, :state, :website, :grade_level, :school_type)
  end

  def omniauth_data
    @omniauth_data ||= session[:auth_data]&.slice("first_name", "last_name", "email")
  end

  def ordered_schools
    if params[:id].present?
      load_teacher
      @ordered_schools ||= [ @teacher.school ] +
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
end
