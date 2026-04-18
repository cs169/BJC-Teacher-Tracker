# frozen_string_literal: true

# == Schema Information
#
# Table name: email_delivery_events
#
#  id                      :bigint           not null, primary key
#  bounce_sub_type         :string
#  bounce_type             :string
#  complaint_feedback_type :string
#  event_occurred_at       :datetime         not null
#  event_type              :string           not null
#  mailer_action           :string
#  message_tags            :jsonb            not null
#  payload                 :jsonb            not null
#  provider                :string           default("aws_ses"), not null
#  recipient_email         :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  email_address_id        :bigint
#  ses_message_id          :string
#  sns_message_id          :string           not null
#  teacher_id              :integer
#
# Indexes
#
#  idx_email_delivery_events_by_email               (email_address_id,event_occurred_at)
#  idx_email_delivery_events_by_teacher             (teacher_id,event_occurred_at)
#  idx_email_delivery_events_by_type                (event_type,event_occurred_at)
#  idx_email_delivery_events_dedupe                 (provider,sns_message_id,recipient_email) UNIQUE
#  index_email_delivery_events_on_email_address_id  (email_address_id)
#  index_email_delivery_events_on_recipient_email   (recipient_email)
#  index_email_delivery_events_on_ses_message_id    (ses_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (email_address_id => email_addresses.id)
#  fk_rails_...  (teacher_id => teachers.id)
#
class EmailDeliveryEvent < ApplicationRecord
  TRACKABLE_EVENT_TYPES = %w[send delivery bounce complaint reject renderingfailure].freeze

  belongs_to :email_address, optional: true
  belongs_to :teacher, optional: true

  validates :provider, :sns_message_id, :event_type, :recipient_email, :event_occurred_at, presence: true
  validates :sns_message_id, uniqueness: { scope: [:provider, :recipient_email] }

  before_validation :normalize_fields

  scope :ordered, -> { order(event_occurred_at: :asc, created_at: :asc) }
  scope :trackable, -> { where(event_type: TRACKABLE_EVENT_TYPES) }
  scope :deliveries, -> { where(event_type: "delivery") }
  scope :complaints, -> { where(event_type: "complaint") }
  scope :rejects, -> { where(event_type: "reject") }
  scope :permanent_bounces, -> { where(event_type: "bounce", bounce_type: "Permanent") }
  scope :suppressing, -> { complaints.or(rejects).or(permanent_bounces) }

  def message_reference
    ses_message_id.presence || "sns:#{sns_message_id}"
  end

  def suppresses_address?
    complaint? || reject? || permanent_bounce?
  end

  def permanent_bounce?
    bounce? && bounce_type == "Permanent"
  end

  private
  def normalize_fields
    self.provider = provider.to_s.presence || "aws_ses"
    self.event_type = event_type.to_s.downcase
    self.recipient_email = recipient_email.to_s.strip.downcase
    self.message_tags ||= {}
    self.payload ||= {}
  end
end
