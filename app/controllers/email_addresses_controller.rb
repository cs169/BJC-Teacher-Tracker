# frozen_string_literal: true

class EmailAddressesController < ApplicationController
  before_action :require_login
  before_action :require_admin
  before_action :set_teacher

  def create
    email = params[:email].to_s.strip
    if email.blank?
      redirect_to teacher_path(@teacher), alert: "No email provided."
      return
    end

    @teacher.email_addresses.create!(email:, primary: false)
    # Sync teacher to MailBluster when a new email is added
    MailblusterService.create_or_update_lead(@teacher) if MailblusterService.configured? && @teacher.validated?
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

    email.destroy!
    # Re-sync to MailBluster since email list changed
    MailblusterService.create_or_update_lead(@teacher) if MailblusterService.configured? && @teacher.validated?
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
end
