# frozen_string_literal: true

class TeacherMailer < ApplicationMailer
  CONTACT_EMAIL = "Lauren Mock <lmock@berkeley.edu>"
  BJC_EMAIL = "BJC <contact@bjc.berkeley.edu>"

  before_action :email_template
  after_action :apply_deliverability_controls
  default content_type: "text/html",
          template_name: "main"

  def welcome_email(teacher)
    @teacher = teacher
    set_body
    set_recipients
    mail to: @recipients, # ActionMailer accepts comma-separated lists of emails
         cc: CONTACT_EMAIL,
         subject: email_template.subject
  end

  def deny_email(teacher, denial_reason)
    @teacher = teacher
    @denial_reason = denial_reason
    set_body
    set_recipients
    mail to: @recipients,
         cc: CONTACT_EMAIL,
         subject: email_template.subject
  end

  def request_info_email(teacher, request_reason)
    @teacher = teacher
    @request_reason = request_reason
    set_body
    set_recipients
    mail to: @recipients,
         cc: CONTACT_EMAIL,
         subject: email_template.subject
  end

  # This method is used to send the /admin/ an email message when a new user signs up.
  def form_submission(teacher)
    @teacher = teacher
    set_body
    set_recipients
    if @teacher.not_reviewed?
      mail to: @recipients,
           subject: email_template.subject
    end
  end

  # teacher form submission works exactly the same as admin form submission,
  # but this method name needs to be explicitly included to ensure that the
  # title inclusion validation passes when updating the EmailTemplate database
  def teacher_form_submission(teacher)
    form_submission(teacher)
  end

  private
  def liquid_assigns
    base_rules = {
      piazza_password: Rails.application.secrets[:piazza_password],
      denial_reason: @denial_reason,
      request_reason: @request_reason,
      request_info_reason: @request_reason
    }
    base_rules.merge!(@teacher.email_attributes)
    base_rules.with_indifferent_access
  end

  def email_template
    @email_template ||= EmailTemplate.find_by(title: action_name.titlecase)
  end

  # renders the email body with the {{parameter}} substitutions
  # Must be called after @teacher is set.
  def set_body
    @body = Liquid::Template.parse(email_template.body).render(liquid_assigns).html_safe
  end

  # renders the list of recipients with the {{parameter}} substitutions
  # Must be called after @teacher is set.
  def set_recipients
    @recipients = Liquid::Template.parse(email_template.to).render(liquid_assigns).html_safe
    @recipients = @recipients.split(",").
        map { |addr| addr.strip }.
        filter { |addr| addr != "(blank)" || addr.blank? }.compact
  end

  def apply_deliverability_controls
    return unless @teacher.present? && message.to.present?

    suppressed = EmailAddress.suppressed.where(email: message.to.map { |r| r.to_s.strip.downcase }).pluck(:email).to_set
    message.to = message.to.reject { |r| suppressed.include?(r.to_s.strip.downcase) }

    if message.to.blank?
      message.perform_deliveries = false
      return
    end

    config_set = ENV["AWS_SES_CONFIGURATION_SET"].to_s
    message["X-SES-CONFIGURATION-SET"] = config_set if config_set.present?
    message["X-SES-MESSAGE-TAGS"] = "app=#{AwsSesEventProcessor::APP_TAG_VALUE}, teacher_id=#{@teacher.id}, mailer_action=#{action_name}"
  end
end
