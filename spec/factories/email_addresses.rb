# frozen_string_literal: true

# == Schema Information
#
# Table name: email_addresses
#
#  id                :bigint           not null, primary key
#  bounced           :boolean          default(FALSE), not null
#  email             :string           not null
#  emails_delivered  :integer          default(0), not null
#  emails_sent       :integer          default(0), not null
#  hard_bounce_count :integer          default(0), not null
#  last_ses_event_at :datetime
#  primary           :boolean          default(FALSE), not null
#  soft_bounce_count :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  teacher_id        :bigint           not null
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
FactoryBot.define do
  factory :email_address do
    association :teacher
    sequence(:email) { |n| "teacher-#{n}@example.edu" }
    primary { false }
  end
end
