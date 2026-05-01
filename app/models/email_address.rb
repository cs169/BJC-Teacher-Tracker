# frozen_string_literal: true

# == Schema Information
#
# Table name: email_addresses
#
#  id               :bigint           not null, primary key
#  bounced          :boolean          default(FALSE), not null
#  email            :string           not null
#  emails_delivered :integer          default(0), not null
#  emails_sent      :integer          default(0), not null
#  primary          :boolean          default(FALSE), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  teacher_id       :bigint           not null
#
# Indexes
#
#  index_email_addresses_on_email                   (email) UNIQUE
#  index_email_addresses_on_teacher_id              (teacher_id)
#  index_email_addresses_on_teacher_id_and_primary  (teacher_id,primary) UNIQUE WHERE ("primary" = true)
#
# Foreign Keys
#
#  fk_rails_...  (teacher_id => teachers.id)
#
class EmailAddress < ApplicationRecord
  belongs_to :teacher

  # Rail's bulit-in validation for email format regex
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :only_one_primary_email_per_teacher

  before_save :normalize_email
  before_save :flag_teacher_if_email_changed

  scope :bounced, -> { where(bounced: true) }
  scope :with_undelivered, -> { where("emails_sent > emails_delivered") }

  # Number of emails that were sent but not delivered.
  def undelivered_count
    [emails_sent - emails_delivered, 0].max
  end

  # Whether this email has any undelivered emails.
  def has_undelivered?
    undelivered_count > 0
  end

  private
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
