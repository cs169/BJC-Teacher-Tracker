# frozen_string_literal: true

class EmailAddressesController < ApplicationController
  before_action :require_login
  before_action :set_teacher
  before_action :require_email_edit_permission

  def create
    email = params[:email].to_s.strip
    if email.blank?
      redirect_to teacher_path(@teacher), alert: "No email provided."
      return
    end

    @teacher.email_addresses.create!(email:, primary: false)
    redirect_to teacher_path(@teacher), notice: "Personal email addresses added successfully."
  rescue ActiveRecord::RecordInvalid => e
    error_message = e.record&.errors&.full_messages&.join(", ")
    error_message ||= "A validation error occurred."
    redirect_to teacher_path(@teacher), alert: error_message
  end

  def destroy
    email = EmailAddress.find(params[:id])
    if email.teacher_id != @teacher.id
      redirect_to teacher_path(@teacher), alert: "Email address not found."
      return
    end

    if @teacher.email_addresses.count <= 1
      redirect_to teacher_path(@teacher), alert: "Add another email before deleting this one."
      return
    end

    email.destroy!
    redirect_to teacher_path(@teacher), notice: "Email address deleted successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to teacher_path(@teacher), alert: "Email address not found."
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to teacher_path(@teacher), alert: "Could not delete email address."
  end

  private
  def set_teacher
    @teacher = Teacher.find(params[:teacher_id])
  end

  def require_email_edit_permission
    return if is_admin? || current_user.id == @teacher.id

    redirect_to edit_teacher_path(current_user.id), alert: "You can only edit your own information"
  end
end
