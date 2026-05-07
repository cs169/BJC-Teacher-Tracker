# frozen_string_literal: true

# ============================================================
# db:staging_seed — Staging / Development Data Seeder
# ============================================================
#
# Run ONCE on a database that already has db:seed applied.
# Adds schools, teachers, PD events, and registrations without
# touching existing data.
#
# Requirements:
#   - A CSV export of schools (schema below)
#   - BACKEND_MAPS_API_KEY with the Geocoding API enabled
#
# Usage:
#   bin/rails "db:staging_seed[/path/to/schools.csv]"
#   bin/rails "db:staging_seed[/path/to/schools.csv,500]"  # limit to 500 schools
#
# CSV column schema:
#   Name, Location, Country, URL, Teachers, Grade Level, Actions
#   (Teachers and Actions columns are ignored)
#
# Other data is scaled proportionally to school count:
#   Teachers         ≈ 1.4 per school (minimum 1 guaranteed)
#   PD Events        ≈ 16% of school count
#   PD Registrations ≈ 3–4 per event
# ============================================================

namespace :db do
  desc "Seed staging/dev from a CSV of schools. Args: [csv_path, limit]"
  task :staging_seed, [:csv_path, :limit] => :environment do |_t, args|
    # ── Arguments ─────────────────────────────────────────────
    csv_path = args[:csv_path].presence
    limit    = args[:limit].to_i.positive? ? args[:limit].to_i : nil

    abort "ERROR: db:staging_seed cannot run in production." if Rails.env.production?
    abort "ERROR: csv_path is required. Usage: bin/rails \"db:staging_seed[/path/to/schools.csv]\"" if csv_path.blank?
    abort "ERROR: BACKEND_MAPS_API_KEY is not set. Schools won't appear on the map without it." unless ENV["BACKEND_MAPS_API_KEY"].present?

    require "csv"

    # ==========================================================
    # SECTION 1 — TEACHER NAME POOLS
    # 47 first names × 44 last names = 2,068 unique combinations
    # ==========================================================

    first_names = %w[
      James Maria David Sarah Michael Jennifer Robert Lisa
      William Patricia Richard Barbara Thomas Susan Charles
      Jessica Daniel Karen Matthew Nancy Anthony Betty Mark
      Dorothy Donald Linda Paul Sandra Kenneth Ashley George
      Priya Wei Amara Fatima Rodrigo Yuki Tariq Aisha
      Mei Kofi Elena Ravi Zara Ingrid Mateus Layla
    ].freeze

    last_names = %w[
      Smith Johnson Williams Brown Jones Garcia Miller Davis
      Rodriguez Martinez Hernandez Lopez Gonzalez Wilson
      Anderson Thomas Taylor Moore Jackson White Harris Martin
      Thompson Robinson Clark Walker Young Allen King Wright
      Patel Nguyen Kim Chen Park Okonkwo Mueller Santos
      Johansson Nakamura Osei Ferreira Kowalski Petrov
    ].freeze

    # ==========================================================
    # SECTION 2 — PD EVENT NAMES
    # ==========================================================

    pd_event_names_by_level = {
      high_school: [
        "BJC Summer Institute",
        "AP CS Principles Curriculum Workshop",
        "CS Education Leadership Conference",
        "BJC Teacher Training Intensive",
        "Computing in High Schools Symposium",
        "High School CS Pedagogy Workshop",
        "Snap! Programming Bootcamp",
        "Equity in CS Education Forum",
        "BJC Facilitator Certification Program",
        "CS Principles Assessment Strategies",
        "Culturally Responsive CS Teaching",
        "BJC Curriculum Deep Dive",
        "High School CS Department Heads Summit",
        "Advanced BJC Techniques Workshop",
        "CS for All Initiative Workshop",
        "High School CS Integration Seminar",
        "BJC Regional Teacher Meetup",
        "CS Pathways and College Readiness Forum",
        "Data Science in High School Workshop",
        "BJC Alumni and Mentor Network Gathering",
      ],
      middle_school: [
        "Middle School CS Fundamentals Workshop",
        "BJC Sparks Curriculum Training",
        "Middle School CS Integration Seminar",
        "Snap! for Middle School Educators",
        "BJC Middle School Facilitator Workshop",
        "Computational Thinking in Middle Grades",
        "Middle School CS Leadership Summit",
        "CS Education Strategies for Grades 6-8",
        "Middle School BJC Curriculum Overview",
        "Hands-On CS Activities for Middle School",
        "BJC Sparks Deep Dive Workshop",
        "Block-Based to Text-Based Transition Seminar",
        "Middle School CS Assessment Workshop",
        "Equity-Centered CS for Middle Grades",
        "Middle School CS Clubs and Outreach",
        "BJC Sparks Regional Training",
        "CS Problem Solving in Middle School",
        "Middle School CS Pedagogy Institute",
        "Game Design and CS Fundamentals",
        "Middle School BJC Instructor Certification",
      ],
      community_college: [
        "Community College CS Integration Workshop",
        "Articulation and Transfer CS Pathways Forum",
        "CS Principles for Two-Year Colleges",
        "BJC in Community College Settings",
        "Dual Enrollment CS Program Workshop",
        "Community College CS Faculty Development",
        "CS Workforce Alignment Seminar",
        "Two-Year College CS Curriculum Symposium",
        "CS Equity in Community Colleges Forum",
        "BJC for Non-Traditional Learners Workshop",
        "Community College CS Assessment Strategies",
        "Open Educational Resources in CS",
        "CS Department Collaboration Forum",
        "Bridging K-12 and Community College CS",
        "Community College CS Pedagogy Institute",
        "Inclusive CS Practices Workshop",
        "CS Lab and Infrastructure Planning Seminar",
        "First-Generation Student CS Success Forum",
        "Community College CS Instructor Retreat",
        "CS Industry Partnerships for Community Colleges",
      ],
      university: [
        "University CS Education Research Symposium",
        "BJC University Partnership Workshop",
        "CS Teacher Preparation Program Seminar",
        "University-K12 CS Pipeline Conference",
        "CS Education Graduate Mentoring Forum",
        "Research-Practice Partnership in CS Ed",
        "University CS Outreach Initiative Workshop",
        "CS Education Policy and Advocacy Seminar",
        "Higher Education BJC Facilitator Training",
        "CS Department Diversity and Inclusion Forum",
        "University CS Curriculum Innovation Workshop",
        "CS Education Data and Learning Analytics",
        "Interdisciplinary CS Education Seminar",
        "University CS Lab Best Practices Forum",
        "CS Capstone and Undergraduate Research Workshop",
        "University CS Faculty Learning Community",
        "Broadening Participation in Computing Summit",
        "CS Graduate Student Teaching Workshop",
        "University CS Accreditation Workshop",
        "CS Education Futures Conference",
      ],
    }.freeze

    # ==========================================================
    # SECTION 3 — WEIGHTED DISTRIBUTIONS & MAPPINGS
    # ==========================================================

    statuses = (
      [:csp_teacher]       * 40 +
      [:non_csp_teacher]   * 15 +
      [:middle_school_bjc] * 15 +
      [:mixed_class]       * 10 +
      [:teals_volunteer]   *  5 +
      [:excite]            *  5 +
      [:home_school_bjc]   *  5 +
      [:other]             *  5
    ).freeze

    app_statuses = (
      [:validated]    * 60 +
      [:not_reviewed] * 20 +
      [:info_needed]  * 10 +
      [:denied]       * 10
    ).freeze

    # If Teacher gains :elementary in the future, it will be picked up automatically.
    # Until then, elementary schools get education_level: nil (column allows NULL).
    elementary_ed_level = Teacher.education_levels.key?("elementary") ? :elementary : nil

    ed_level_for = {
      elementary:        elementary_ed_level,
      middle_school:     :middle_school,
      high_school:       :high_school,
      community_college: :college,
      university:        :college,
    }.freeze

    grade_level_from_string = ->(raw) {
      case raw.to_s.strip.downcase
      when /middle|junior high/                       then :middle_school
      when /high/                                     then :high_school
      when /community college|two.year|2.year/        then :community_college
      when /university|college|four.year|4.year|inst/ then :university
      when /elementary/                               then :elementary
      end
    }

    # ==========================================================
    # SECTION 4 — CREATE SCHOOLS FROM CSV
    # Geocoding fires automatically via the School before_save
    # callback since we don't supply lat/lng.
    # ==========================================================

    puts "Creating schools..."
    new_schools      = []
    skip_no_city     = 0
    skip_country     = 0
    skip_state       = 0
    skip_grade_level = 0

    rows = CSV.read(csv_path, headers: true)
    rows = rows.first(limit) if limit

    rows.each do |row|
      name            = row["Name"]&.strip
      location_raw    = row["Location"].to_s.strip
      country_raw     = row["Country"].to_s.strip
      url             = row["URL"].to_s.strip
      grade_level_raw = row["Grade Level"].to_s.strip

      next if name.blank?

      parts = location_raw.split(",").map(&:strip)
      city  = parts[0].presence
      if city.blank?
        skip_no_city += 1
        next
      end

      # Resolve any valid ISO alpha2 or alpha3 code to alpha2 for the School model.
      # If Country column is blank, check if a location part is a country code.
      # Unrecognized values are skipped.
      country = if country_raw.present?
        found = ISO3166::Country[country_raw.upcase] ||
                ISO3166::Country.find_country_by_alpha3(country_raw.upcase)
        if found
          found.alpha2
        else
          skip_country += 1
          next
        end
      else
        # Country column blank — scan location parts for an embedded country code
        embedded = parts.map(&:upcase).find { |p|
          ISO3166::Country[p] && !School::VALID_STATES.include?(p)
        }
        embedded ? ISO3166::Country[embedded].alpha2 : "US"
      end

      state = country == "US" ? parts[1]&.gsub(/\W/, "")&.upcase&.first(2) : nil

      if country == "US" && (state.blank? || !School::VALID_STATES.include?(state))
        skip_state += 1
        next
      end

      grade_level = grade_level_from_string.(grade_level_raw)
      if grade_level.nil?
        skip_grade_level += 1
        next
      end

      website = url.match?(/\..+/) ? url : "https://#{name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+/, '-').first(40)}.edu"

      school = School.find_or_create_by!(name:, city:, country:) do |s|
        s.state       = state
        s.website     = website
        s.grade_level = grade_level
        s.school_type = :public
        # lat/lng omitted — before_save callback geocodes using BACKEND_MAPS_API_KEY
      end

      new_schools << school if school.previously_new_record?
    end

    puts "  Created #{new_schools.size} schools."

    # ==========================================================
    # SECTION 5 — CREATE TEACHERS
    # Every school gets at least 1 teacher. Schools at positions
    # where idx % 5 < 2 get 2. Education level matches school.
    # Email is globally unique: first.last@schoolslug{id}.edu
    # ==========================================================

    puts "Creating teachers..."
    teacher_index = 0

    new_schools.each_with_index do |school, school_idx|
      teachers_per_school = (school_idx % 5 < 2) ? 2 : 1
      school_slug = school.name.downcase.gsub(/[^a-z0-9]+/, "").first(16)

      teachers_per_school.times do
        first = first_names[teacher_index % first_names.size]
        last  = last_names[(teacher_index / first_names.size) % last_names.size]
        email = "#{first.downcase}.#{last.downcase}@#{school_slug}#{school.id}.edu"

        app_status = app_statuses[teacher_index % app_statuses.size]

        teacher = Teacher.create!(
          first_name:         first,
          last_name:          last,
          snap:               "#{first.downcase}_#{last.downcase[0..3]}#{teacher_index}",
          status:             statuses[teacher_index % statuses.size],
          application_status: app_status,
          education_level:    ed_level_for[school.grade_level.to_sym],
          personal_website:   "https://#{school_slug}#{school.id}.edu/faculty/#{first.downcase}-#{last.downcase}",
          school:
        )

        # Only validated/denied teachers have received emails.
        # ~3% hard bounce, ~3% soft bounce among those teachers.
        if [:validated, :denied].include?(app_status)
          bounce_idx = teacher_index % 100
          bounce_type = if bounce_idx < 3   then :hard
          elsif bounce_idx < 6 then :soft
          else                      :none
          end
          emails_sent      = bounce_type == :soft ? 2 : (teacher_index % 3) + 1
          emails_delivered = case bounce_type
                             when :hard then 0
                             when :soft then 1  # retried and eventually delivered
                             else emails_sent
          end
        else
          bounce_type      = :none
          emails_sent      = 0
          emails_delivered = 0
        end

        EmailAddress.create!(
          teacher:,
          email:,
          primary:           true,
          emails_sent:,
          emails_delivered:,
          bounced:           bounce_type == :hard,
          hard_bounce_count: bounce_type == :hard ? 1 : 0,
          soft_bounce_count: bounce_type == :soft ? 1 : 0,
          last_ses_event_at: emails_sent > 0 ? Time.current - (teacher_index % 30).days : nil
        )

        teacher_index += 1
      end
    end

    puts "  Created #{teacher_index} teachers."

    # ==========================================================
    # SECTION 6 — CREATE PROFESSIONAL DEVELOPMENT EVENTS
    # Count is proportional to school count (~16%, minimum 4).
    # ==========================================================

    puts "Creating professional development events..."

    pd_count = [(new_schools.size * 0.16).round, 4].max
    pd_slots = []
    max_names = pd_event_names_by_level.values.map(&:size).max
    max_names.times do |i|
      pd_event_names_by_level.each do |level, names|
        pd_slots << [level, names[i]] if i < names.size
        break if pd_slots.size >= pd_count
      end
      break if pd_slots.size >= pd_count
    end

    pd_records = pd_slots.map.with_index do |(grade_level, name), idx|
      year      = 2023 + (idx % 3)
      month     = (idx % 10) + 1
      start_day = (idx % 20) + 1
      end_day   = [start_day + 2 + (idx % 3), Date.new(year, month, -1).day].min

      # Use a US school for PD location (PD events are always US)
      school = new_schools.select { |s| s.country == "US" }[idx % new_schools.size] ||
               new_schools[idx % new_schools.size]

      ProfessionalDevelopment.create!(
        name:       "#{name} #{year}",
        city:       school.city,
        state:      school.state.presence || "CA",
        country:    "US",
        start_date: Date.new(year, month, start_day),
        end_date:   Date.new(year, month, end_day),
        grade_level:
      )
    end

    puts "  Created #{pd_records.size} PD events."

    # ==========================================================
    # SECTION 7 — CREATE PD REGISTRATIONS
    # ==========================================================

    puts "Creating PD registrations..."

    pd_ed_level_for = {
      "high_school"       => :high_school,
      "middle_school"     => :middle_school,
      "community_college" => :college,
      "university"        => :college,
    }

    new_school_ids = new_schools.map(&:id)
    teachers_by_level = {
      high_school:   Teacher.where(school_id: new_school_ids, admin: false, education_level: :high_school).ids,
      middle_school: Teacher.where(school_id: new_school_ids, admin: false, education_level: :middle_school).ids,
      college:       Teacher.where(school_id: new_school_ids, admin: false, education_level: :college).ids,
    }

    pd_records.each_with_index do |pd, pd_idx|
      ed_level = pd_ed_level_for[pd.grade_level]
      pool     = teachers_by_level[ed_level] || []
      next if pool.empty?

      attendee_count = 2 + (pd_idx % 3)
      offset         = (pd_idx * 5) % pool.size
      candidate_ids  = (pool[offset..] + pool[0...offset]).first(attendee_count + 1)

      Teacher.where(id: candidate_ids).each_with_index do |teacher, i|
        next if PdRegistration.exists?(teacher:, professional_development: pd)

        PdRegistration.create!(
          teacher:,
          professional_development: pd,
          role:                     i == 0 ? "leader" : "attendee",
          attended:                 i == 0 || (pd_idx + i).even?
        )
      end
    end

    # ==========================================================
    # SECTION 8 — CREATE PAGES
    # Requires an admin teacher (created by db:seed).
    # ==========================================================

    puts "Creating pages..."

    admin = Teacher.find_by(admin: true)

    if admin.nil?
      puts "  Skipping pages — no admin teacher found. Run db:seed first."
    else
      pages_data = [
        {
          title:              "Welcome to BJC",
          url_slug:           "welcome",
          category:           "General",
          viewer_permissions: "Public",
          default:            true,
          html:               <<~HTML
            <h1>Welcome to the Beauty and Joy of Computing</h1>
            <p>
              The Beauty and Joy of Computing (BJC) is a College Board-endorsed AP Computer Science
              Principles curriculum developed at UC Berkeley. BJC emphasizes the creative and
              collaborative aspects of computing, connecting CS to real-world impacts in art, science,
              and society.
            </p>
            <h2>Getting Started</h2>
            <ul>
              <li><strong>New teacher?</strong> Submit your application and our team will review it within a few days.</li>
              <li><strong>Already validated?</strong> Log in to access the full curriculum, teacher guides, and community resources.</li>
              <li><strong>Questions?</strong> Reach out to us at <a href="mailto:contact@bjc.berkeley.edu">contact@bjc.berkeley.edu</a>.</li>
            </ul>
            <h2>About the Curriculum</h2>
            <p>
              BJC is built around the Snap<em>!</em> visual programming language and covers all seven
              Big Ideas of the AP CS Principles framework. Lessons are inquiry-based, culturally
              responsive, and designed to engage students of all backgrounds — especially those
              historically underrepresented in computing.
            </p>
          HTML
        },
        {
          title:              "Teacher Resources",
          url_slug:           "teacher-resources",
          category:           "Resources",
          viewer_permissions: "Verified Teacher",
          default:            false,
          html:               <<~HTML
            <h1>Teacher Resources</h1>
            <p>Welcome to the BJC teacher resource hub. Everything below is exclusive to validated BJC teachers.</p>
            <h2>Curriculum Materials</h2>
            <ul>
              <li><a href="https://bjc.edc.org/bjc-r/course/bjc4nyc.html">BJC Course (Snap! Labs)</a></li>
              <li><a href="https://bjc.edc.org">BJC Website</a> — syllabus, pacing guides, and unit overviews</li>
              <li>Teacher editions and answer keys are linked within each unit on the BJC site.</li>
            </ul>
            <h2>Snap! Programming</h2>
            <ul>
              <li><a href="https://snap.berkeley.edu">Snap! Editor</a> — the programming environment used in BJC</li>
              <li><a href="https://snap.berkeley.edu/tutorials">Snap! Tutorials</a> — beginner to advanced</li>
            </ul>
            <h2>Community</h2>
            <ul>
              <li>BJC Teacher Forum — connect with teachers across the country</li>
              <li>Annual BJC Summer Institute — intensive PD, typically held each July at UC Berkeley</li>
              <li>Regional workshops listed on the Professional Development page</li>
            </ul>
            <h2>Assessment</h2>
            <p>
              The AP CS Principles exam includes a performance task (Create Task) and an end-of-course
              exam. BJC's labs are designed to prepare students for both components. See the
              <a href="https://apcentral.collegeboard.org/courses/ap-computer-science-principles">
              College Board AP CSP page</a> for scoring guidelines and sample responses.
            </p>
          HTML
        },
        {
          title:              "AP CS Principles Exam Guide",
          url_slug:           "ap-csp-exam-guide",
          category:           "Resources",
          viewer_permissions: "Verified Teacher",
          default:            false,
          html:               <<~HTML
            <h1>AP CS Principles Exam Guide</h1>
            <p>
              This guide summarizes what BJC teachers need to know about the AP CSP exam, College Board
              requirements, and how BJC aligns to the framework.
            </p>
            <h2>Exam Structure</h2>
            <ul>
              <li><strong>Create Performance Task (30%)</strong> — students develop a program of their choice and submit a written response. Completed in class prior to the exam date.</li>
              <li><strong>End-of-Course Exam (70%)</strong> — 70 multiple choice questions covering all seven Big Ideas.</li>
            </ul>
            <h2>BJC Alignment to the Big Ideas</h2>
            <ol>
              <li>Creative Development</li>
              <li>Data</li>
              <li>Algorithms and Programming</li>
              <li>Computer Systems and Networks</li>
              <li>Impact of Computing</li>
            </ol>
            <p>BJC covers all five Big Ideas across its seven units. See the pacing guide on bjc.edc.org for unit-by-Big-Idea mapping.</p>
            <h2>Course Audit</h2>
            <p>
              To offer AP CSP for credit, your course must pass the College Board Course Audit.
              BJC's syllabi are pre-approved — download the endorsed syllabus from the BJC website
              and submit it through AP Classroom.
            </p>
          HTML
        },
        {
          title:              "Admin Handbook",
          url_slug:           "admin-handbook",
          category:           "Admin",
          viewer_permissions: "Admin",
          default:            false,
          html:               <<~HTML
            <h1>BJC Teacher Tracker — Admin Handbook</h1>
            <p>This page documents processes for admins reviewing teacher applications and managing the tracker.</p>
            <h2>Reviewing Applications</h2>
            <ol>
              <li>Navigate to <strong>Teachers → Unreviewed</strong> to see pending applications.</li>
              <li>Check the teacher's school, website, and teaching status for plausibility.</li>
              <li>Set application status to <strong>Validated</strong>, <strong>Denied</strong>, or <strong>Info Needed</strong>.</li>
              <li>Use the Verification Notes field to record your reasoning — especially for denials.</li>
            </ol>
            <h2>Email & MailBluster</h2>
            <p>
              Validated teachers are synced to MailBluster for newsletter delivery. If a teacher's
              email shows a hard bounce, mark them accordingly and follow up before re-sending.
              Soft bounces may resolve on their own — retry after 48 hours.
            </p>
            <h2>Merging Duplicates</h2>
            <p>
              Duplicate teacher or school records can be merged via the Merge tools in the admin panel.
              Always verify the merge direction (which record is kept) before confirming — merges
              are not reversible.
            </p>
            <h2>Data Export</h2>
            <p>
              A full CSV export of all teachers is available from the Teachers index page.
              Exports include email delivery stats, school info, and application status.
            </p>
          HTML
        },
      ]

      pages_data.each do |attrs|
        next if Page.exists?(url_slug: attrs[:url_slug])
        Page.create!(attrs.merge(creator: admin, last_editor: admin))
      end

      puts "  Created #{pages_data.size} pages."
    end

    # ==========================================================
    # SUMMARY
    # ==========================================================

    new_teacher_count = Teacher.where(school_id: new_school_ids).count
    new_email_count   = EmailAddress.where(teacher: Teacher.where(school_id: new_school_ids)).count

    puts ""
    geocode_failures = new_schools.count { |s| s.lat.nil? }
    total_skipped    = skip_no_city + skip_country + skip_state + skip_grade_level

    puts "Staging seed complete!"
    puts "  Schools created:       #{new_schools.size}"
    puts "  Schools skipped:       #{total_skipped}"
    puts "    Missing city:        #{skip_no_city}"
    puts "    Unrecognized country:#{skip_country}"
    puts "    Invalid/missing state:#{skip_state}"
    puts "    Missing grade level: #{skip_grade_level}"
    puts "  Geocoding failures:    #{geocode_failures} (schools saved without coordinates)"
    puts "  Teachers created:      #{new_teacher_count}"
    puts "  Email addresses:       #{new_email_count}"
    puts "  PD events created:     #{pd_records.size}"
    puts "  PD registrations:      #{PdRegistration.where(professional_development: pd_records).count}"
    puts "  Pages in DB:           #{Page.count}"
    puts ""
    puts "  Total schools in DB:   #{School.count}"
    puts "  Total teachers in DB:  #{Teacher.count}"
  end
end
