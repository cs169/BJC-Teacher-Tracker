# frozen_string_literal: true

# Demo seed tasks for BJC Teacher Tracker.
# Generated with Claude (claude-sonnet-4-6).
#
# ─────────────────────────────────────────────────────────────────────────────
# TASKS
# ─────────────────────────────────────────────────────────────────────────────
#
# demo:seed [csv_path]
#   Populates the DB with schools, teachers, pages, and PD data.
#   Run AFTER db:seed (which creates email templates and admin teachers).
#   Safe to re-run — purely additive, never deletes existing records.
#
#   School source (choose one):
#     • Pass a CSV path → loads up to 100 schools from the file. Maximum can be changed below.
#       CSV must have columns: name, location (e.g. "City, ST"), country, url, grade_level
#     • Omit the path   → generates ~30 Faker schools + 10 intentional near-duplicates
#       for testing the school merge feature (e.g. two "Lincoln High School" entries).
#
#   Geocoding during seed:
#     Coordinates are resolved at city-level granularity (one Maps API call per unique
#     city, not per school) to stay well within rate limits. Schools in the same city
#     share the same lat/lng pin. Requires GOOGLE_MAPS_API_KEY; if unset, schools are
#     inserted without coordinates (no map pins) and a warning is printed.
#
# demo:geocode_schools
#   Re-geocodes ALL schools using school-name-level precision ("School Name, City, State"),
#   overwriting any city-level coordinates set during demo:seed. Run this after demo:seed
#   for more accurate map pins. Requires GOOGLE_MAPS_API_KEY.
#
# ─────────────────────────────────────────────────────────────────────────────
# USAGE — local
# ─────────────────────────────────────────────────────────────────────────────
#
#   bin/rails db:seed                                    # prereq: email templates + admins
#   bin/rails demo:seed                                  # Faker schools
#   bin/rails 'demo:seed[/path/to/schools.csv]'          # CSV schools (quote for zsh)
#   bin/rails demo:geocode_schools                       # optional: school-level precision
#   set -a; source .env; set +a;                         # Run before geocode if you don't have dotenv gem
#
# ─────────────────────────────────────────────────────────────────────────────
# USAGE — Heroku
# ─────────────────────────────────────────────────────────────────────────────
#
#   heroku run rails db:seed
#   heroku run rails demo:seed
#   heroku run rails demo:geocode_schools                # optional

namespace :demo do
  desc "Geocode all schools using school-name-level precision, overwriting existing coordinates."
  task geocode_schools: :environment do
    abort "GOOGLE_MAPS_API_KEY is not set." unless ENV["GOOGLE_MAPS_API_KEY"].present?

    total = School.count
    puts "Geocoding all #{total} schools by school name..."

    updated = 0
    failed  = 0
    School.find_each do |school|
      query  = "#{school.name}, #{school.location}".sub("International", "")
      coords = MapsService.get_lat_lng(query)
      if coords
        # update_columns bypasses before_save so we don't re-trigger the GPS callback
        school.update_columns(lat: coords[:lat], lng: coords[:lng])
        updated += 1
        puts "  ✓ #{query}"
      else
        failed += 1
        puts "  ✗ #{query} (not found)"
      end
      sleep(0.05) # 50 ms between requests to avoid transient rate-limit errors
    end

    still_missing = School.where(lat: nil).or(School.where(lng: nil)).count
    puts "Updated #{updated} / #{total} schools with coordinates."
    puts "#{still_missing} schools still have no coordinates (re-run to retry)." if still_missing > 0
  end

  desc "Seed the development database with realistic demo data. " \
       "Accepts an optional path to a schools CSV file."
  task :seed, [:csv_path] => :environment do |_t, args|
    # factory_bot_rails Railtie already called FactoryBot.find_definitions after
    # the environment loaded — do NOT call it again or you'll get DuplicateDefinitionError.

    csv_path = args[:csv_path].presence

    puts "\n=== BJC Dev Seed ==="

    # --- Schools ---
    school_data = build_school_data(csv_path)
    puts "Geocoding #{school_data.size} schools by unique city..."
    geocode_schools!(school_data)
    puts "Inserting schools..."
    inserted_schools = insert_schools(school_data)
    puts "  #{inserted_schools.size} schools in DB."

    # --- Teachers ---
    puts "Creating teachers..."
    all_teachers = create_teachers(inserted_schools)
    puts "  Created #{all_teachers.size} teachers."

    # --- Pages ---
    # Prefer an admin teacher as creator; fall back to any teacher
    page_author = Teacher.find_by(admin: true) || Teacher.first
    if page_author
      puts "Creating pages..."
      page_count = create_pages(page_author)
      puts "  Created #{page_count} pages."
    else
      puts "  Skipping pages (no teachers in DB yet — run db:seed first)."
    end

    # --- Professional Developments ---
    puts "Creating professional developments..."
    pds = create_professional_developments
    puts "  Created #{pds.size} professional developments."

    # --- PD Registrations ---
    puts "Creating PD registrations..."
    reg_count = create_pd_registrations(all_teachers, pds)
    puts "  Created #{reg_count} registrations."

    puts "\nDone! Summary:"
    puts "  Schools:                     #{School.count}"
    puts "  Teachers (non-admin):        #{Teacher.where(admin: false).count}"
    puts "  Admin teachers:              #{Teacher.where(admin: true).count}"
    puts "  Pages:                       #{Page.count}"
    puts "  Professional developments:   #{ProfessionalDevelopment.count}"
    puts "  PD registrations:            #{PdRegistration.count}"
  end

  # ---------------------------------------------------------------------------
  # School data builders
  # ---------------------------------------------------------------------------

  GRADE_LEVEL_MAP = {
    "elementary"        => 0,
    "middle school"     => 1,
    "high school"       => 2,
    "community college" => 3,
    "university"        => 4,
  }.freeze

  MAX_CSV_SCHOOLS = 100

  def build_school_data(csv_path)
    if csv_path.present?
      puts "Loading up to #{MAX_CSV_SCHOOLS} schools from CSV: #{csv_path}"
      schools_from_csv(csv_path)
    else
      puts "No CSV found — generating schools with Faker."
      schools_from_faker
    end
  end

  def schools_from_csv(csv_path)
    now = Time.current

    # Without chunk_size, SmarterCSV returns a flat array of row hashes
    rows = SmarterCSV.process(csv_path, remove_empty_values: false)

    rows.first(MAX_CSV_SCHOOLS).filter_map do |row|
      name    = row[:name].to_s.strip
      raw_loc = row[:location].to_s.strip.delete_suffix(",")
      country = row[:country].to_s.strip.presence || "US"
      website = row[:url].to_s.strip
      grade   = row[:grade_level].to_s.strip.downcase

      next if name.blank? || website.blank?

      city, state = parse_location(raw_loc, country)
      next if country == "US" && state.blank?

      {
        name:        name,
        city:        city.presence || "Unknown",
        state:       state,
        country:     country,
        website:     website,
        grade_level: GRADE_LEVEL_MAP[grade] || 2,
        school_type: 0,
        lat:         nil,
        lng:         nil,
        created_at:  now,
        updated_at:  now,
      }
    end
  end

  def schools_from_faker
    now = Time.current
    us_states = School::VALID_STATES

    schools = 30.times.map do
      state = us_states.sample
      {
        name:        "#{Faker::Educator.university} #{["Academy", "Charter School", "High School"].sample}",
        city:        Faker::Address.city,
        state:       state,
        country:     "US",
        website:     Faker::Internet.url,
        grade_level: GRADE_LEVEL_MAP.values.sample,
        school_type: rand(0..5),
        lat:         nil,
        lng:         nil,
        created_at:  now,
        updated_at:  now,
      }
    end

    # Intentional near-duplicate school names for testing the merge feature
    %w[Lincoln Jefferson Lincoln Jefferson].each do |president|
      2.times do
        schools << {
          name:        "#{president} High School",
          city:        Faker::Address.city,
          state:       us_states.sample,
          country:     "US",
          website:     Faker::Internet.url,
          grade_level: 2,
          school_type: 0,
          lat:         nil,
          lng:         nil,
          created_at:  now,
          updated_at:  now,
        }
      end
    end

    schools
  end

  # ---------------------------------------------------------------------------
  # Geocoding — one Maps API call per unique city, not per school
  # ---------------------------------------------------------------------------

  def geocode_schools!(school_data)
    unless ENV["GOOGLE_MAPS_API_KEY"].present?
      puts "  WARNING: GOOGLE_MAPS_API_KEY not set — schools will be inserted without coordinates (no map pins)."
      return
    end

    unique_locations = school_data
      .map { |s| geocode_key(s[:city], s[:state], s[:country]) }
      .uniq

    puts "  #{unique_locations.size} unique locations to geocode..."
    location_coords = {}
    geocoded = 0
    failed   = 0

    unique_locations.each do |loc|
      coords = MapsService.get_lat_lng(loc)
      if coords
        location_coords[loc] = { lat: coords[:lat], lng: coords[:lng] }
        geocoded += 1
      else
        location_coords[loc] = { lat: nil, lng: nil }
        failed += 1
      end
    end

    puts "  Geocoded: #{geocoded}, not found: #{failed}"

    school_data.each do |school|
      key = geocode_key(school[:city], school[:state], school[:country])
      school.merge!(location_coords[key])
    end
  end

  # ---------------------------------------------------------------------------
  # Database insertion — bulk insert bypasses before_save GPS callback
  # since lat/lng are already populated by geocode_schools!
  # (name+city+website has no UNIQUE index, so we filter duplicates manually)
  # ---------------------------------------------------------------------------

  def insert_schools(school_data)
    return [] if school_data.empty?

    # Filter out schools that already exist by (name, city, website)
    existing = School.pluck(:name, :city, :website).to_set
    new_data  = school_data.reject { |s| existing.include?([s[:name], s[:city], s[:website]]) }

    puts "  Skipping #{school_data.size - new_data.size} already-existing schools."
    School.insert_all(new_data) if new_data.any?
    School.all.to_a
  end

  # ---------------------------------------------------------------------------
  # Teachers (3–8 per school, via FactoryBot so email_addresses are created)
  # ---------------------------------------------------------------------------

  def create_teachers(schools)
    application_statuses = ["Validated", "Not Reviewed", "Info Needed", "Denied"]
    teacher_statuses     = Teacher.statuses.values
    teachers             = []

    schools.each do |school|
      rand(1..7).times do
        first_name = Faker::Name.first_name
        last_name  = Faker::Name.last_name
        email      = Faker::Internet.unique.email(name: "#{first_name} #{last_name}")
        snap       = [Faker::Internet.username(specifier: "#{first_name.downcase}#{last_name.downcase}"), nil].sample

        teacher = FactoryBot.create(
          :teacher,
          first_name:         first_name,
          last_name:          last_name,
          snap:               snap,
          school:             school,
          status:             teacher_statuses.sample,
          application_status: application_statuses.sample,
          admin:              false,
          personal_website:   [Faker::Internet.url, nil].sample,
        )
        teacher.email_addresses.find_by(primary: true).update!(email: email)
        teachers << teacher
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        Rails.logger.debug "Skipping teacher: #{e.message}"
      end
    end

    teachers
  end

  # ---------------------------------------------------------------------------
  # Pages
  # ---------------------------------------------------------------------------

  def create_pages(admin)
    sample_pages = [
      {
        title:              "Welcome to BJC",
        url_slug:           "welcome",
        viewer_permissions: "Public",
        default:            true,
        category:           "General",
        html:               "<h1>Welcome to the Beauty and Joy of Computing!</h1>" \
                            "<p>BJC is a CS Principles curriculum developed at UC Berkeley.</p>",
      },
      {
        title:              "Teacher Resources",
        url_slug:           "teacher-resources",
        viewer_permissions: "Verified Teacher",
        default:            false,
        category:           "Resources",
        html:               "<h1>Teacher Resources</h1><p>Slides, guides, and lesson plans for BJC teachers.</p>",
      },
      {
        title:              "Curriculum Overview",
        url_slug:           "curriculum-overview",
        viewer_permissions: "Verified Teacher",
        default:            false,
        category:           "Curriculum",
        html:               "<h1>Curriculum Overview</h1><p>Unit summaries and learning objectives.</p>",
      },
      {
        title:              "Admin Guide",
        url_slug:           "admin-guide",
        viewer_permissions: "Admin",
        default:            false,
        category:           "Administration",
        html:               "<h1>Admin Guide</h1><p>Instructions for BJC Teacher Tracker administrators.</p>",
      },
      {
        title:              "Professional Development",
        url_slug:           "pd-info",
        viewer_permissions: "Public",
        default:            false,
        category:           "General",
        html:               "<h1>Professional Development</h1><p>Information about upcoming BJC workshops and PD opportunities.</p>",
      },
    ]

    count = 0
    sample_pages.each do |attrs|
      Page.find_or_create_by(url_slug: attrs[:url_slug]) do |page|
        page.assign_attributes(attrs.merge(creator: admin, last_editor: admin))
        count += 1
      end
    end
    count
  end

  # ---------------------------------------------------------------------------
  # Professional Developments
  # ---------------------------------------------------------------------------

  def create_professional_developments
    us_states = School::VALID_STATES

    pd_names = [
      "BJC Summer Institute",
      "BJC Spring Workshop",
      "Intro to CS Principles",
      "BJC Curriculum Deep Dive",
      "AP CS Principles Bootcamp",
      "BJC Regional Training",
      "BJC Online Cohort",
      "Snap! Programming Workshop",
      "Middle School CS Workshop",
      "BJC Advanced Seminar",
    ]

    pd_names.map do |name|
      state      = us_states.sample
      start_date = Faker::Date.between(from: 1.year.ago, to: 1.year.from_now)
      end_date   = start_date + rand(1..5)

      ProfessionalDevelopment.find_or_create_by(name: name) do |pd|
        pd.city        = Faker::Address.city
        pd.state       = state
        pd.country     = "US"
        pd.start_date  = start_date
        pd.end_date    = end_date
        pd.grade_level = rand(0..4)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PD Registrations — connect validated teachers to PD events
  # ---------------------------------------------------------------------------

  def create_pd_registrations(teachers, pds)
    validated = teachers.select(&:validated?)
    count     = 0

    pds.each do |pd|
      attendees = validated.sample(rand(5..15))
      attendees.each_with_index do |teacher, i|
        PdRegistration.create!(
          teacher:                  teacher,
          professional_development: pd,
          role:                     i.zero? ? "leader" : "attendee",
          attended:                 [true, false].sample,
        )
        count += 1
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        next
      end
    end

    count
  end

  # ---------------------------------------------------------------------------
  # Location parsing
  # ---------------------------------------------------------------------------

  # Build the geocoding query string matching the School model's own maps_api_location logic:
  # US schools use "City, State" (no country) — appending "US" causes ZERO_RESULTS from Google.
  # Non-US schools use "City, State, Country".
  def geocode_key(city, state, country)
    if country == "US"
      [city, state].compact.join(", ")
    else
      [city, state, country].compact.join(", ").sub("International", "")
    end
  end

  # Parse "City, ST" or "City, ST," into [city, state].
  def parse_location(location_str, country)
    parts = location_str.split(",").map(&:strip).reject(&:blank?)
    city  = parts[0].to_s.strip

    if country == "US"
      state = parts[1].to_s.strip.upcase
      state = nil unless School::VALID_STATES.include?(state)
      [city, state]
    else
      [city, parts[1].to_s.strip.presence]
    end
  end
end
