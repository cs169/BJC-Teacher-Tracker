# frozen_string_literal: true

class TeacherMailer < ApplicationMailer
  CONTACT_EMAIL = 'Lauren Mock <lmock@berkeley.edu>'
  TEALS_CONTACT_EMAIL = Rails.application.secrets[:teals_contact_email]&.freeze
  BJC_EMAIL = 'BJC <contact@bjc.berkeley.edu>'
  BJC_PASSWORD = Rails.application.secrets[:bjc_password]
  PIAZZA_PASSWORD = Rails.application.secrets[:piazza_password]

  def welcome_email(teacher)
    @teacher = teacher
    @bjc_password = BJC_PASSWORD
    @piazza_password = PIAZZA_PASSWORD
    mail to: @teacher.email_name,
         cc: CONTACT_EMAIL,
         subject: 'Welcome to The Beauty and Joy of Computing!'
  end

  def deny_email(teacher, reason)
    @teacher = teacher
    @reason = reason.to_s
    @bjc_password = BJC_PASSWORD
    @piazza_password = PIAZZA_PASSWORD
    mail to: @teacher.email_name,
         cc: CONTACT_EMAIL,
         subject: 'Deny Email'
  end

  def teals_confirmation_email(teacher)
    @teacher = teacher
    if !@teacher.status.nil? and @teacher.teals_volunteer?
      @bjc_password = BJC_PASSWORD
      @piazza_password = PIAZZA_PASSWORD
      mail to: TEALS_CONTACT_EMAIL,
           cc: CONTACT_EMAIL,
           subject: 'TEALS Confirmation Email'
    end
  end

  def form_submission(teacher)
    @teacher = teacher
    mail to: CONTACT_EMAIL, subject: "A New Teacher Has Requested Access to BJC"
  end
end
