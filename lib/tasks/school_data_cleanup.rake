

namespace :schools do

  desc "Report (and optionally fix) schools with missing or invalid country"
  task fix_countries: :environment do
    apply = ENV["APPLY"] == "true"

    puts apply ? "\n=== APPLYING country fixes ===" : "\n=== DRY RUN — pass APPLY=true to save ==="
    puts ""

    valid_codes = ISO3166::Country.all.map(&:alpha2).to_set

    us_states = School::VALID_STATES.to_set

    generic_tlds = %w[com org edu net io gov mil int info].to_set

    bad_schools = School.where(country: [nil, ""])
                        .or(School.where.not(country: valid_codes.to_a))

    puts "Found #{bad_schools.count} school(s) with missing/invalid country.\n\n"

    fixed   = 0
    skipped = 0

    bad_schools.find_each do |school|
      proposed_country = nil
      method_used      = nil

      if school.state.present? && us_states.include?(school.state.strip.upcase)
        proposed_country = "US"
        method_used = "US state abbreviation '#{school.state}'"
      end

      if proposed_country.nil? && school.website.present?
        begin
          host = URI.parse(school.website).host
          if host.present?
            tld = host.split(".").last.upcase

            if !generic_tlds.include?(tld.downcase) && valid_codes.include?(tld)
              proposed_country = tld
              method_used = "website TLD '.#{tld.downcase}'"
            end
          end
        rescue URI::InvalidURIError
        end
      end

      if proposed_country.nil? && school.lat.present? && school.lng.present?
        country_from_coords = reverse_geocode_country(school.lat, school.lng)
        if country_from_coords && valid_codes.include?(country_from_coords)
          proposed_country = country_from_coords
          method_used = "reverse geocoding (#{school.lat}, #{school.lng})"
        end
      end

      if proposed_country
        puts "  [FIX] ##{school.id} \"#{school.name}\" (#{school.city}, #{school.state})"
        puts "         Current country: #{school.country.inspect}"
        puts "         Proposed:        #{proposed_country}  (via #{method_used})"

        if apply
          school.update_column(:country, proposed_country)
          puts "         ✓ Saved."
        end

        fixed += 1
      else
        puts "  [SKIP] ##{school.id} \"#{school.name}\" (#{school.city}, #{school.state})"
        puts "         website: #{school.website.inspect}  lat/lng: #{school.lat}, #{school.lng}"
        puts "         ⚠ Could not infer country — needs manual review."
        skipped += 1
      end

      puts ""
    end

    puts "---"
    puts "Total:   #{bad_schools.count}"
    puts "Fixable: #{fixed}   |   Needs manual review: #{skipped}"
    puts apply ? "All fixable records have been updated." : "(Dry run — no changes written.)"
    puts ""
  end

  desc "Report (and optionally fix) schools with likely-wrong grade levels"
  task fix_grade_levels: :environment do
    apply = ENV["APPLY"] == "true"

    puts apply ? "\n=== APPLYING grade-level fixes ===" : "\n=== DRY RUN — pass APPLY=true to save ==="
    puts ""

    name_keywords = {
      "community college" => :community_college,
      "university"        => :university,
      "college"           => :university,
      "high school"       => :high_school,
      "middle school"     => :middle_school,
      "elementary"        => :elementary,
      "primary school"    => :elementary,
    }

    teacher_to_school_grade = {
      "middle_school" => :middle_school,
      "high_school"   => :high_school,
      "college"       => :university,
    }

    schools = School.includes(:teachers).order(:name)

    puts "Scanning #{schools.count} school(s)...\n\n"

    flagged = 0

    schools.find_each do |school|
      current_grade = school.grade_level

      name_suggestion = nil
      lower_name = school.name.to_s.downcase
      name_keywords.each do |keyword, grade_sym|
        if lower_name.include?(keyword)
          name_suggestion = grade_sym
          break
        end
      end

      teacher_suggestion = nil

      teachers_with_level = school.teachers.select do |t|
        t.education_level_before_type_cast.present? &&
          t.education_level_before_type_cast.to_i >= 0
      end

      if teachers_with_level.any?
        level_counts = teachers_with_level
          .group_by(&:education_level)
          .transform_values(&:count)

        most_common_teacher_level = level_counts.max_by { |_level, count| count }&.first

        if most_common_teacher_level && teacher_to_school_grade.key?(most_common_teacher_level)
          teacher_suggestion = teacher_to_school_grade[most_common_teacher_level]
        end
      end

      name_mismatch    = name_suggestion    && name_suggestion.to_s    != current_grade
      teacher_mismatch = teacher_suggestion && teacher_suggestion.to_s != current_grade

      next unless name_mismatch || teacher_mismatch

      both_agree = name_mismatch && teacher_mismatch &&
                   name_suggestion == teacher_suggestion
      confidence = both_agree ? "HIGH" : "LOW"

      proposed = if both_agree
                   name_suggestion
                 elsif name_mismatch
                   name_suggestion
                 else
                   teacher_suggestion
                 end

      flagged += 1

      puts "  [#{confidence} CONFIDENCE] ##{school.id} \"#{school.name}\""
      puts "    Current grade_level:  #{current_grade || '(nil)'}"
      puts "    Proposed grade_level: #{proposed}"

      if name_mismatch
        puts "    ↳ Name contains keyword suggesting: #{name_suggestion}"
      end

      if teacher_mismatch
        teacher_summary = teachers_with_level
          .group_by(&:education_level)
          .transform_values(&:count)
          .map { |level, cnt| "#{level}=#{cnt}" }
          .join(", ")
        puts "    ↳ Teacher education levels (#{teachers_with_level.size} teachers): #{teacher_summary}"
        puts "      Majority suggests school should be: #{teacher_suggestion}"
      end

      if apply && both_agree
        school.update_column(:grade_level, School.grade_levels[proposed])
        puts "    ✓ Saved (high confidence)."
      elsif apply
        puts "    ⊘ Skipped (low confidence — review manually)."
      end

      puts ""
    end

    puts "---"
    puts "Total schools scanned: #{schools.count}"
    puts "Flagged:               #{flagged}"
    puts apply ? "High-confidence fixes have been applied." : "(Dry run — no changes written.)"
    puts ""
  end
end

def reverse_geocode_country(lat, lng)
  api_key = ENV["BACKEND_MAPS_API_KEY"]

  if api_key.blank?
    @_geo_warning_shown ||= begin
      puts "  ⚠ BACKEND_MAPS_API_KEY is not set — skipping reverse geocoding."
      true
    end
    return nil
  end

  url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=#{lat},#{lng}&key=#{api_key}"

  response = HTTParty.get(url)

  return nil unless response["status"] == "OK"

  components = response.dig("results", 0, "address_components") || []
  country_component = components.find { |c| c["types"].include?("country") }

  country_component&.dig("short_name")
rescue StandardError => e
  puts "  ⚠ Reverse geocoding failed for (#{lat}, #{lng}): #{e.message}"
  nil
end
