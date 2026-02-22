# frozen_string_literal: true

# == Schema Information
#
# Table name: teachers
#
#  id                 :integer          not null, primary key
#  admin              :boolean          default(FALSE)
#  application_status :string           default("not_reviewed")
#  education_level    :integer          default(NULL)
#  email              :string
#  first_name         :string
#  ip_history         :inet             default([]), is an Array
#  languages          :string           default(["\"English\""]), is an Array
#  last_name          :string
#  last_session_at    :datetime
#  more_info          :string
#  personal_email     :string
#  personal_website   :string
#  session_count      :integer          default(0)
#  snap               :string
#  status             :integer
#  created_at         :datetime
#  updated_at         :datetime
#  school_id          :integer
#
# Indexes
#
#  index_teachers_on_email                     (email) UNIQUE
#  index_teachers_on_email_and_first_name      (email,first_name)
#  index_teachers_on_email_and_personal_email  (email,personal_email) UNIQUE
#  index_teachers_on_school_id                 (school_id)
#  index_teachers_on_snap                      (snap) UNIQUE WHERE ((snap)::text <> ''::text)
#  index_teachers_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (school_id => schools.id)
#
class Teacher < ApplicationRecord
  # TODO: Move this somewhere else...
  WORLD_LANGUAGES = [ "Afrikaans", "Albanian", "Arabic", "Armenian", "Basque", "Bengali", "Bulgarian", "Catalan", "Cambodian", "Chinese (Mandarin)", "Croatian", "Czech", "Danish", "Dutch", "English", "Estonian", "Fiji", "Finnish", "French", "Georgian", "German", "Greek", "Gujarati", "Hebrew", "Hindi", "Hungarian", "Icelandic", "Indonesian", "Irish", "Italian", "Japanese", "Javanese", "Korean", "Latin", "Latvian", "Lithuanian", "Macedonian", "Malay", "Malayalam", "Maltese", "Maori", "Marathi", "Mongolian", "Nepali", "Norwegian", "Persian", "Polish", "Portuguese", "Punjabi", "Quechua", "Romanian", "Russian", "Samoan", "Serbian", "Slovak", "Slovenian", "Spanish", "Swahili", "Swedish ", "Tamil", "Tatar", "Telugu", "Thai", "Tibetan", "Tonga", "Turkish", "Ukrainian", "Urdu", "Uzbek", "Vietnamese", "Welsh", "Xhosa" ].freeze

  has_many :email_addresses, dependent: :destroy
  has_many_attached :files
  has_many_attached :more_files
  accepts_nested_attributes_for :email_addresses, allow_destroy: true

  validates :first_name, :last_name, :status, presence: true
  validate :valid_languages
  before_validation :sort_and_clean_languages

  # Custom attribute for tracking email changes. This is not persisted in the database.
  attribute :email_changed_flag, :boolean, default: false

  enum application_status: {
    validated: "Validated",
    denied: "Denied",
    info_needed: "Info Needed",
    not_reviewed: "Not Reviewed",
  }
  validates_inclusion_of :application_status, in: application_statuses.keys

  belongs_to :school, counter_cache: true
  has_many :professional_development_registrations
  has_many :professional_developments, through: :professional_development_registrations

  # Non-admin teachers whose application has neither been accepted nor denied
  # It might or might not have been reviewed.
  # TODO: Ensure these scopes do not override enum names.
  scope :unvalidated, -> { where("(application_status=? OR application_status=?) AND admin=?", application_statuses[:info_needed], application_statuses[:not_reviewed], "false") }
  scope :unreviewed, -> { where("application_status=? AND admin=?", application_statuses[:not_reviewed], "false") }
  # Non-admin teachers who have been accepted/validated
  scope :validated, -> { where("application_status=? AND admin=?", application_statuses[:validated], "false") }


  # TODO: Remove this.
  enum education_level: {
    middle_school: 0,
    high_school: 1,
    college: 2
  }

  # The order of these two lists must match.
  # Do NOT change the values of existing options.
  enum status: {
    csp_teacher: 0,
    non_csp_teacher: 1,
    mixed_class: 2,
    teals_volunteer: 3,
    other: 4,
    teals_teacher: 5,
    developer: 6,
    excite: 7,
    middle_school_bjc: 8,
    home_school_bjc: 9
  }

  # Always add to the bottom of the list!
  # The text here may be changed, but the index maps to the actual reason (above)
  STATUSES = [
    "I am teaching BJC as an AP CS Principles course.",
    "I am teaching BJC but not as an AP CS Principles course.",
    "I am using BJC as a resource, but not teaching with it.",
    "I am a TEALS volunteer, and am teaching the BJC curriculum.",
    "Other - Please specify below.",
    "I am teaching BJC through the TEALS program.",
    "I am a BJC curriculum or tool developer.",
    "I am teaching with the ExCITE project",
    "I am teaching Middle School BJC.",
    "I am teaching homeschool with the BJC curriculum."
  ].freeze

  # From an admin perspective, we want to know if a teacher has any **meaningful** change
  # that would require re-reviewing their application.
  before_update :check_for_relevant_changes

  delegate :name, :location, :grade_level, :website, to: :school, prefix: true
  delegate :school_type, to: :school # don't add a redundant prefix.

  def check_for_relevant_changes
    ignored_fields = %w[created_at updated_at session_count last_session_at ip_history]
    # if any relevant fields have changed
    if (changes.keys - ignored_fields).present?
      handle_relevant_changes
    end
  end

  def handle_relevant_changes
    reset_validation_status
  end

  def reset_validation_status
    return if application_status_changed? || school_id_changed?
    if info_needed?
      not_reviewed!
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def email_name
    # We need to normalize names for emails.
    "#{full_name} <#{primary_email}>".delete(",")
  end

  # TODO: Remove this pending migration to drop email column.
  def email
    # Default return primary email
    primary_email
  end

  def primary_email
    email_addresses.find_by(primary: true)&.email
  end

  def personal_emails
    non_primary_emails
  end

  # TODO: use this method until we rename the column.
  def snap_username
    self.snap
  end

  def try_append_ip(ip)
    return if ip_history.include?(ip)
    self.ip_history << ip
    save
  end

  def status=(value)
    value = value.to_i if value.is_a?(String)
    super(value)
  end

  def text_status
    STATUSES[status_before_type_cast]
  end

  def display_status
    formatted_status = status.to_s.titlecase
    return "#{formatted_status} | #{more_info}" if more_info?
    formatted_status
  end
  # TODO: Move these to helpers.
  def self.status_options
    display_order = [
      :csp_teacher,
      :middle_school_bjc,
      :non_csp_teacher,
      :mixed_class,
      :excite,
      :teals_teacher,
      :teals_volunteer,
      :home_school_bjc,
      :other,
      :developer,
    ]

    display_order.map do |key|
      status_idx = statuses[key]
      [ STATUSES[status_idx], status_idx ]
    end
  end

  def display_languages
    languages.join(", ")
  end

  def valid_languages
    !languages.empty? && languages.all? { |value| WORLD_LANGUAGES.include?(value) }
  end

  def sort_and_clean_languages
    # Due to an identified bug in the Selectize plugin, an empty string is occasionally appended to the 'languages' list.
    # To ensure data integrity, the following code removes any occurrences of empty strings from the list.
    languages.sort!.reject!(&:blank?)
  end
  # TODO: Move to a helper.
  def self.application_status_options
    Teacher.application_statuses.map { |sym, val| [sym.to_s.titlecase, val] }
  end

  def self.education_level_options
    Teacher.education_levels.map { |sym, val| [sym.to_s.titlecase, val] }
  end

  def self.language_options
    WORLD_LANGUAGES
  end

  def display_education_level
    if education_level_before_type_cast.to_i == -1
      "?"
    else
      education_level.to_s.titlecase
    end
  end

  def display_application_status
    application_status.titlecase
  end

  def short_application_status
    {
      validated: "✔️",
      denied: "🚫",
      not_reviewed: "✉️",
      info_needed: "❓",
    }[application_status.to_sym]
  end

  def self.user_from_omniauth(omniauth)
    email = EmailAddress.find_by(email: omniauth.email.downcase)

    # We should handle this separately.
    # Trim emails that end with email+snap-id-XXX@domain which come from the snap forum
    if email.blank? && omniauth.email.match?(/\+snap-id-\d+/)
      email = EmailAddress.find_by(email: omniauth.email.downcase.gsub(/\+snap-id-\d+@/, "@"))
    end
    email&.teacher
  end

  def email_attributes
    {
      teacher_first_name: self.first_name,
      teacher_last_name: self.last_name,
      teacher_full_name: self.full_name,
      teacher_primary_email: self.primary_email,
      teacher_email: self.primary_email,
      # TODO: change to personal_emails
      teacher_personal_email: self.non_primary_emails.join(", "),
      teacher_more_info: self.more_info,
      teacher_snap_username: self.snap_username,
      teacher_education_level: self.education_level,
      teacher_personal_website: self.personal_website,
      teacher_teaching_status: self.text_status,
      teacher_signed_up_at: self.created_at,

      # TODO: Move these to the school model.
      teacher_school_name: self.school.name,
      teacher_school_city: self.school.city,
      teacher_school_state: self.school.state,
      teacher_school_website: self.school.website,
    }.transform_values { |value| value.blank? ? "(blank)" : value }
  end

  # TODO: The school data needs to be cleaned up.
  def self.csv_export
    attributes = %w|
      id
      full_name
      first_name
      last_name
      email
      personal_email
      snap_username
      education_level
      display_application_status
      text_status
      more_info
      created_at
      session_count
      school_id
      school_name
      school_location
      school_website
      school_grade_level
      school_type
    |

    CSV.generate(headers: true) do |csv|
      csv << attributes

      Teacher.where(admin: false).find_each do |user|
        csv << attributes.map { |attr| user.send(attr) }
      end
    end
  end

  private
  def non_primary_emails
    email_addresses.where(primary: false)&.pluck(:email)
  end
end
