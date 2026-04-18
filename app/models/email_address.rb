# frozen_string_literal: true

# == Schema Information
#
# Table name: email_addresses
#
#  id                       :bigint           not null, primary key
#  bounced                  :boolean          default(FALSE), not null
#  email                    :string           not null
#  emails_delivered         :integer          default(0), not null
#  emails_sent              :integer          default(0), not null
#  last_delivery_event_at   :datetime
#  last_delivery_event_type :string
#  primary                  :boolean          default(FALSE), not null
#  suppressed_at            :datetime
#  suppression_reason       :string
#  suppression_source       :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  teacher_id               :bigint           not null
#
# Indexes
#
#  index_email_addresses_on_email                   (email) UNIQUE
#  index_email_addresses_on_last_delivery_event_at  (last_delivery_event_at)
#  index_email_addresses_on_suppressed_at           (suppressed_at)
#  index_email_addresses_on_teacher_id              (teacher_id)
#  index_email_addresses_on_teacher_id_and_primary  (teacher_id,primary) UNIQUE WHERE ("primary" = true)
#
# Foreign Keys
#
#  fk_rails_...  (teacher_id => teachers.id)
#
class EmailAddress < ApplicationRecord
  belongs_to :teacher
  has_many :email_delivery_events, dependent: :destroy

  # Rail's bulit-in validation for email format regex
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :only_one_primary_email_per_teacher

  before_save :normalize_email
  before_save :flag_teacher_if_email_changed

  scope :bounced, -> { where(bounced: true) }
  scope :suppressed, -> { where.not(suppressed_at: nil) }
  scope :deliverable, -> { where(suppressed_at: nil) }
  scope :with_undelivered, -> { where("emails_sent > emails_delivered") }
  scope :with_deliverability_issues, -> { where.not(suppressed_at: nil).or(where("emails_sent > emails_delivered")) }

  # Number of emails that were sent but not delivered.
  def undelivered_count
    [emails_sent - emails_delivered, 0].max
  end

  # Whether this email has any undelivered emails.
  def has_undelivered?
    undelivered_count > 0
  end

  def suppressed?
    suppressed_at.present?
  end

  def deliverable?
    !suppressed?
  end

  def recalculate_deliverability!
    sent_count = distinct_message_count(email_delivery_events.trackable)
    delivered_count = distinct_message_count(email_delivery_events.deliveries)
    last_event = email_delivery_events.ordered.last
    suppression_event = email_delivery_events.suppressing.ordered.last

    update_columns(
      emails_sent: sent_count,
      emails_delivered: delivered_count,
      bounced: email_delivery_events.permanent_bounces.exists?,
      suppressed_at: suppression_event&.event_occurred_at,
      suppression_reason: suppression_reason_for(suppression_event),
      suppression_source: suppression_event&.provider,
      last_delivery_event_type: last_event&.event_type,
      last_delivery_event_at: last_event&.event_occurred_at,
      updated_at: Time.current
    )
  end

  private
  def distinct_message_count(relation)
    relation.to_a.map(&:message_reference).uniq.count
  end

  def suppression_reason_for(event)
    return nil unless event
    return "complaint" if event.complaint?
    return "provider_reject" if event.reject?
    return "hard_bounce" if event.permanent_bounce?

    nil
  end

  def only_one_primary_email_per_teacher
    if primary? && EmailAddress.where(teacher_id:, primary: true).where.not(id:).exists?
      errors.add(:primary, "There can only be one primary email per teacher.")
    end
  end

  def normalize_email
    self.email = email.strip.downcase
  end

  def flag_teacher_if_email_changed
    if self.email_changed? && !self.new_record?
      teacher.email_changed_flag = true
      teacher.handle_relevant_changes
    end
  end
end
