# frozen_string_literal: true

# == Schema Information
#
# Table name: schools
#
#  id             :integer          not null, primary key
#  city           :string
#  country        :string
#  grade_level    :integer
#  lat            :float
#  lng            :float
#  name           :string
#  school_type    :integer
#  state          :string
#  tags           :text             default([]), is an Array
#  teachers_count :integer          default(0)
#  website        :string
#  created_at     :datetime
#  updated_at     :datetime
#  nces_id        :string
#
# Indexes
#
#  index_schools_on_name_city_and_website  (name,city,website)
#

class School < ApplicationRecord
  VALID_STATES = ISO3166::Country["US"].subdivisions.keys.freeze
  validates :name, :city, :website, :country, presence: true
  validates :country, inclusion: { in: ISO3166::Country.all.map(&:alpha2), message: "%{value} is not a valid country" }
  validates :state, presence: true, if: -> { country == "US" }
  validates :state, inclusion: { in: VALID_STATES }, if: -> { country == "US" }
  validates_format_of :website, with: /.+\..+/, on: :create
  validates :grade_level, presence: true
  validates :school_type, presence: true

  before_save :update_gps_data, if: -> { lat.nil? || lng.nil? || location_changed? }

  has_many :teachers
  scope :validated, -> { where("teachers_count > 0") }

  enum grade_level: {
    elementary: 0,
    middle_school: 1,
    high_school: 2,
    community_college: 3,
    university: 4
  }

  enum school_type: {
    public: 0,
    private: 1,
    charter: 2,
    magnet: 3,
    alternative: 4,
    other: 5
  }, _prefix: :school_type

  def website
    prefix_url(self[:website])
  end

  def location
    country_text = country == "US" ? "" : ", #{country}"
    "#{city}, #{state}#{country_text}"
  end

  # TODO: Consider renaming this.
  def equal(school)
    return false unless school.present?

    self.name == school.name && self.state == school.state && self.city == school.city && school.website == self.website
  end

  def display_grade_level
    return "Unknown" if grade_level_before_type_cast.to_i == -1

    grade_level.to_s.titlecase
  end

  def selectize_options
    [name_location, to_json(only: [:id, :name, :city, :state, :country, :website]) ]
  end

  def name_location
    "#{name} (#{city}, #{state}, #{country})"
  end

  def update_gps_data
    data = MapsService.get_lat_lng(maps_api_location)
    return unless data

    self.lat = data[:lat]
    self.lng = data[:lng]
  end

  def maps_marker_data
    {
      name: name_location,
      id: id,
      position: { lat:, lng: },
    }
  end

  def format_school(data)
    name, city, state, country = data
    country_str = country == "US" ? "" : ", #{country}"
    "#{name} (#{city}, #{state}#{country_str})"
  end

  def self.search_list
    School.pluck(:name, :city, :state, :country).map(&:format_school)
  end

  def self.grade_level_options
    School.grade_levels.map { |key, _val| [key.to_s.titlecase, key] }
  end

  def self.school_type_options
    School.school_types.map { |key, _val| [key.to_s.titlecase, key] }
  end

  def self.all_maps_data
    validated.map(&:maps_marker_data).to_json
  end

  private
  def location_changed?
    city_changed? || state_changed? || country_changed?
  end

  def prefix_url(url)
    return unless url
    url.match?(/^https?:/) ? url : "https://#{url}"
  end

  def maps_api_location
    "#{name}, #{location}".sub("International", "")
  end
end
