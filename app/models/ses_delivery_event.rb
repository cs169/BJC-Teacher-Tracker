# frozen_string_literal: true

class SesDeliveryEvent < ApplicationRecord
  EVENT_TYPES = %w[Send Delivery Bounce Complaint].freeze

  belongs_to :email_address, optional: true

  validates :sns_message_id, presence: true
  validates :event_type, presence: true
  validates :recipient_email, presence: true
  validates :event_occurred_at, presence: true

  scope :hard_bounces, -> { where("event_type = 'Complaint' OR (event_type = 'Bounce' AND bounce_type <> 'Transient')") }
  scope :soft_bounces, -> { where(event_type: "Bounce", bounce_type: "Transient") }
end
