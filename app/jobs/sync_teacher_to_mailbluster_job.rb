# frozen_string_literal: true

class SyncTeacherToMailblusterJob < ApplicationJob
  queue_as :default

  def perform(teacher_id)
    teacher = Teacher.includes(:email_addresses, :school).find_by(id: teacher_id)
    return unless teacher
    return unless MailblusterService.configured?
    return unless teacher.validated? || teacher.mailbluster_id.present?

    MailblusterService.create_or_update_lead(teacher)
  end
end