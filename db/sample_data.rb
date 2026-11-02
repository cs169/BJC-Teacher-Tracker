# frozen_string_literal: true

# Demo schools and teachers for development and staging.
# Loaded by `bin/rails db:seed:sample_data`; never part of `db:seed`.
#
# Every address uses a reserved example domain (RFC 2606), so seeded mail can
# never reach a real person.
module SampleData
  SCHOOLS = [
    { name: "Lincoln High School", city: "San Francisco", state: "CA", country: "US",
      website: "https://lincolnhs.example", grade_level: 2, school_type: 0 },
    { name: "Riverside Middle School", city: "Austin", state: "TX", country: "US",
      website: "https://riverside-ms.example", grade_level: 1, school_type: 0 },
    { name: "Greenfield Charter Academy", city: "Portland", state: "OR", country: "US",
      website: "https://greenfieldcharter.example", grade_level: 2, school_type: 2 },
    { name: "Eastside Prep", city: "New York", state: "NY", country: "US",
      website: "https://eastsideprep.example", grade_level: 2, school_type: 1 },
    { name: "Pacific Community College", city: "Seattle", state: "WA", country: "US",
      website: "https://pacificcc.example", grade_level: 3, school_type: 0 },
  ].freeze

  def self.create_schools
    SCHOOLS.each do |attrs|
      school = School.find_or_initialize_by(attrs.slice(:name, :city, :state, :country))
      school.update!(attrs)
    end
  end

  # Call after create_schools so the school lookups resolve.
  def self.teachers
    [
      { first_name: "Priya", last_name: "Ramirez", status: 0, snap: "priya_ram",
        application_status: "Validated", personal_website: "https://priyaramirez.example",
        personal_email: "priya.ramirez@example.com", education_level: 1,
        languages: ["English", "Spanish"], school: school("Lincoln High School"),
        email: "pramirez@lincolnhs.example" },
      { first_name: "James", last_name: "Okonkwo", status: 1, snap: "jokonkwo_cs",
        application_status: "Validated", personal_website: "https://okonkwo-teaches.example",
        personal_email: "james.okonkwo@example.com", education_level: 0,
        languages: ["English"], school: school("Riverside Middle School"),
        email: "jokonkwo@riverside-ms.example" },
      { first_name: "Sofia", last_name: "Chen", status: 0, snap: "sofia_chen_cs",
        application_status: "Not Reviewed", personal_website: "https://sofiacsclass.example",
        education_level: 1, languages: ["English", "Chinese (Mandarin)"],
        school: school("Greenfield Charter Academy"), email: "schen@greenfieldcharter.example" },
      { first_name: "Marcus", last_name: "Williams", status: 2, snap: "mwilliams_bjc",
        application_status: "Validated", personal_website: "https://mwilliamscs.example",
        education_level: 1, languages: ["English"], school: school("Eastside Prep"),
        email: "mwilliams@eastsideprep.example" },
      { first_name: "Aisha", last_name: "Patel", status: 0, snap: "aisha_p",
        application_status: "Info Needed", personal_website: "https://aishapatel.example",
        personal_email: "aisha.patel@example.com", education_level: 2,
        more_info: "Currently setting up a new CS program at the college.",
        languages: ["English", "Hindi"], school: school("Pacific Community College"),
        email: "apatel@pacificcc.example" },
      { first_name: "Diego", last_name: "Morales", status: 5, snap: "diego_teals",
        application_status: "Validated", personal_website: "https://dmorales-teals.example",
        personal_email: "diego.morales@example.com", education_level: 1,
        languages: ["English", "Spanish"], school: school("Lincoln High School"),
        email: "dmorales@lincolnhs.example" },
      { first_name: "Emily", last_name: "Nakamura", status: 8, snap: "emily_nak",
        application_status: "Denied", personal_website: "https://nakamura-cs.example",
        education_level: 0, verification_notes: "Could not verify school affiliation.",
        languages: ["English", "Japanese"], school: school("Riverside Middle School"),
        email: "enakamura@riverside-ms.example" },
      { first_name: "Tariq", last_name: "Hassan", status: 0, snap: "tariq_h",
        application_status: "Validated", personal_website: "https://tariqhassan.example",
        personal_email: "tariq.hassan@example.com", education_level: 1,
        languages: ["English", "Arabic"], school: school("Eastside Prep"),
        email: "thassan@eastsideprep.example" },
      { first_name: "Rachel", last_name: "Novak", status: 0, snap: "rnovak_cs",
        application_status: "Validated", personal_website: "https://rachelnovak.example",
        personal_email: "rachel.novak@example.com", education_level: 1,
        languages: ["English", "Czech"], school: school("Lincoln High School"),
        email: "rnovak@lincolnhs.example" },
      { first_name: "Kevin", last_name: "Tran", status: 1, snap: "kevtran_bjc",
        application_status: "Not Reviewed", personal_website: "https://kevintran.example",
        education_level: 2, languages: ["English", "Vietnamese"],
        school: school("Pacific Community College"), email: "ktran@pacificcc.example" },
      { first_name: "Fatima", last_name: "Al-Rashid", status: 7, snap: "fatima_excite",
        application_status: "Validated", personal_website: "https://fatimaalrashid.example",
        personal_email: "fatima.alrashid@example.com", education_level: 1,
        languages: ["English", "Arabic", "French"], school: school("Greenfield Charter Academy"),
        email: "falrashid@greenfieldcharter.example" },
      { first_name: "Mia", last_name: "Johansson", status: 0, snap: "mia_johan",
        application_status: "Validated", personal_website: "https://miajohansson.example",
        personal_email: "mia.johansson@example.com", education_level: 1,
        languages: ["English", "Norwegian"], school: school("Eastside Prep"),
        email: "mjohansson@eastsideprep.example" },
    ]
  end

  # Secondary addresses for teachers who list a personal email.
  def self.email_addresses
    teachers.filter_map do |t|
      next if t[:personal_email].blank?

      { email: t[:personal_email], primary: false, owner: t[:email] }
    end
  end

  def self.school(name)
    School.find_by(name:)
  end
end
