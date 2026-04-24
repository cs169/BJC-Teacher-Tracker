# frozen_string_literal: true

module SeedData
  @welcome_email = <<-WELCOME_EMAIL
    <p>Hi {{teacher_first_name}},<br /><br />Thanks for teaching with BJC!</p>

    <p><strong>Accessing the teacher's guide:</strong><br />To view the <a title="teacher's guide" href="https://bjc.edc.org/teacher" target="_blank" rel="noopener">teacher's guide</a>, you will login to the teacher tracker.<br /><br />After you enter the password once it will be stored in a cookie for that browser; if you delete your browser cookies, you will need to reenter it. If you use this password on a computer that students also use, they will have access to these pages until you clear the cookies. <br /><br />Please note that only the Teacher Guide <em>solutions</em> pages are affected by this. Students will still be able to see the Teacher Guide course overview page, the Teacher Resources page, and the Teacher Guide unit overview pages.</p>

    <p><strong>Piazza:</strong> <br />We have a teacher's forum on <a href="https://piazza.com" target="_blank" rel="noopener">Piazza</a>, where we will share updates and you can get your questions answered. If you have not been added to Piazza, you can add yourself using this email address. Go to our <a href="https://piazza.com/cs10k/other/bjcteachers" target="_blank" rel="noopener">BJC Teachers Forum</a>&nbsp;(<a href="https://piazza.com/cs10k/other/bjcteachers" target="_blank" rel="noopener">https://piazza.com/cs10k/other/bjcteachers/home</a>). Then enter the code <code>{{piazza_password}}</code> to get access. Please do not share this login information with anyone!</p>

    <p><strong>Snap<em>!</em></strong><br />We encourage you to check out the <a href="https://forum.snap.berkeley.edu'" target="_blank" rel="noopener">Snap<em>!</em> Forum</a>. If you have Snap<em>!</em>-specific questions, you can reach out to the Snap<em>!</em> team at <a href="mailto:contact@snap.berkeley.edu" target="_blank" rel="noopener">contact@snap.berkeley.edu</a>.</p>

    <p>Thank you! <br />&mdash; The BJC Team</p>
  WELCOME_EMAIL

  @form_submission = <<-FORM_SUBMISSION
    <p>
      View form submission {{view_teacher_url}}<br>
      Here is the information that was submitted: <br>
      Name: {{teacher_first_name}} {{teacher_last_name}} <br>
      Email: {{teacher_email}} <br>
      Snap Username: {{teacher_snap_username | link_to(teacher_snap_username, "https://snap.berkeley.edu/user?username=" + teacher_snap_username )}} <br>
      School: {{teacher_school_name}} <br>
      Location: {{teacher_school_city}}, {{teacher_school_state}} <br>
      Website: {{ teacher_school_website | link_to(nil, teacher_school_website) }}
    </p>
  FORM_SUBMISSION

  @basic_email_with_reason = <<-DENY_EMAIL
    <p>
      {{ denial_reason | strip_tags }}
    </p>
  DENY_EMAIL

  @deny_email = <<-DENY_EMAIL1
    <p>Dear [Recipient's Name],</p>
    <p>Thank you for your email. We have received your message and we are sorry to inform you that your application has been rejected.</p>
    <p>Best regards,</p>
    <p>[Your Name]</p>
    <p>Below, you can find the reason as to why it was rejected </p>
    <p>
      {{ denial_reason | strip_tags}}
    </p>
  DENY_EMAIL1

  @deny_email2 = <<-DENY_EMAIL2
    <p>Dear [Recipient's Name],</p>
    <p>Thank you for your email. We have received your message and we are sorry to inform you that your application has been rejected.</p>
    <p>Best regards,</p>
    <p>[Your Name]</p>
    <p>Unfortunately, we are not able to provide a particular reason at this moment </p>
  DENY_EMAIL2

  @deny_email3 = <<-DENY_EMAIL3
    <p>Dear [Recipient's Name],</p>
    <p>Thank you for your email. We have received your message and your application has currently been waitlisted.</p>
    <p>We will reach out to you if there are any changes to your application, </p>
    <p>Best regards,</p>
    <p>[Your Name]</p>

  DENY_EMAIL3

  @request_info_email = <<-REQUEST_INFO_EMAIL
    <p>Dear {{teacher_first_name}},</p>

    <p>We hope this message finds you well. We're writing to you regarding your ongoing application with BJC. As part of our review process, we've identified that some additional information is required to move forward.</p>

    <p><strong>Required Information:</strong><br>
    We kindly ask you to provide the following details to complete your application:</p>
    <p>{{ request_reason | strip_tags }}</p>

    <p>To submit the requested information, please follow these steps:</p>
    <ol>
      <li>Log into your BJC account using your registered email and password.</li>
      <li>Locate your current application and update the information.</li>
      <li>Fill in the necessary details in the provided fields and submit the update.</li>
    </ol>

    <p>Thank you for your attention to this matter. We look forward to receiving the additional information and advancing your application process.</p>

    <p>Warm regards,</p>
    <p>[Your Name]</p>
  REQUEST_INFO_EMAIL


  @default_to_field = "{{teacher_email}}, {{teacher_personal_email}}"

  def self.emails
    [
      {
        to: @default_to_field,
        body: @welcome_email,
        path: "teacher_mailer/welcome_email",
        locale: nil,
        handler: "liquid",
        partial: false,
        format: "html",
        title: "Welcome Email",
        required: true,
        subject: "Welcome to The Beauty and Joy of Computing!"
      },
      { # admin form submission email
        to: "lmock@berkeley.edu, contact@bjc.berkeley.edu",
        body: @form_submission,
        path: "teacher_mailer/form_submission",
        locale: nil,
        handler: "liquid",
        partial: false,
        format: "html",
        title: "Form Submission",
        required: true,
        subject: "Form Submission"
      },
      { # teacher form submission email
        to: @default_to_field,
        body: @form_submission,
        path: "teacher_mailer/teacher_form_submission",
        locale: nil,
        handler: "liquid",
        partial: false,
        format: "html",
        title: "Teacher Form Submission",
        required: true,
        subject: "Teacher Form Submission"
      },
      {
        to: @default_to_field,
        body: @deny_email,
        path: "teacher_mailer/deny_email",
        locale: nil,
        handler: "liquid",
        partial: false,
        format: "html",
        title: "Deny Email",
        required: true,
        subject: "Deny Email"
      },
      {
        body: @request_info_email,
        to: @default_to_field,
        path: "teacher_mailer/request_info_email",
        locale: nil,
        handler: "liquid",
        partial: false,
        format: "html",
        title: "Request Info Email",
        required: true,
        subject: "Request Info Email"
      }
    ]
  end

  def self.create_schools
    schools = [
      {
        name: "UC Berkeley",
        city: "Berkeley",
        state: "CA",
        country: "US",
        website: "https://bjc.berkeley.edu",
        grade_level: 4,
        school_type: 0
      },
      {
        name: "Lincoln High School",
        city: "San Francisco",
        state: "CA",
        country: "US",
        website: "https://lincolnhs.org",
        grade_level: 2,
        school_type: 0
      },
      {
        name: "Riverside Middle School",
        city: "Austin",
        state: "TX",
        country: "US",
        website: "https://riverside-ms.edu",
        grade_level: 1,
        school_type: 0
      },
      {
        name: "Greenfield Charter Academy",
        city: "Portland",
        state: "OR",
        country: "US",
        website: "https://greenfieldcharter.org",
        grade_level: 2,
        school_type: 2
      },
      {
        name: "Eastside Prep",
        city: "New York",
        state: "NY",
        country: "US",
        website: "https://eastsideprep.edu",
        grade_level: 2,
        school_type: 1
      },
      {
        name: "Pacific Community College",
        city: "Seattle",
        state: "WA",
        country: "US",
        website: "https://pacificcc.edu",
        grade_level: 3,
        school_type: 0
      }
    ]

    schools.each do |attrs|
      school = School.find_or_initialize_by(
        name: attrs[:name],
        city: attrs[:city],
        state: attrs[:state],
        country: attrs[:country]
      )
      school.update!(attrs)
    end
  end

  def self.teachers
    [
        {
            first_name: "Michael",
            last_name: "Ball",
            admin: true,
            status: 0,
            application_status: "Validated",
            personal_website: "https://example.com",
            school: School.find_by(name: "UC Berkeley"),

            # Note: email field does not exist in the schema of the Teacher model
            # Include it in the seed data is to simulate the behavior of creating a new teacher,
            # because we need to use it to compared with the EmailAddress model,
            # to determine the existence of the teacher
            email: "ball@berkeley.edu",
        },
        {
            first_name: "Lauren",
            last_name: "Mock",
            admin: true,
            status: 0,
            application_status: "Validated",
            personal_website: "https://example.com",
            school: School.find_by(name: "UC Berkeley"),

            email: "lmock@berkeley.edu",
        },
        {
            first_name: "Priya",
            last_name: "Ramirez",
            admin: false,
            status: 0,
            snap: "priya_ram",
            application_status: "Validated",
            personal_website: "https://priyaramirez.dev",
            personal_email: "priya.ramirez@gmail.com",
            education_level: 1,
            languages: ["English", "Spanish"],
            school: School.find_by(name: "Lincoln High School"),
            email: "pramirez@lincolnhs.org",
        },
        {
            first_name: "James",
            last_name: "Okonkwo",
            admin: false,
            status: 1,
            snap: "jokonkwo_cs",
            application_status: "Validated",
            personal_website: "https://okonkwo-teaches.com",
            personal_email: "james.okonkwo@outlook.com",
            education_level: 0,
            languages: ["English"],
            school: School.find_by(name: "Riverside Middle School"),
            email: "jokonkwo@riverside-ms.edu",
        },
        {
            first_name: "Sofia",
            last_name: "Chen",
            admin: false,
            status: 0,
            snap: "sofia_chen_cs",
            application_status: "Not Reviewed",
            personal_website: "https://sofiacsclass.com",
            education_level: 1,
            languages: ["English", "Mandarin"],
            school: School.find_by(name: "Greenfield Charter Academy"),
            email: "schen@greenfieldcharter.org",
        },
        {
            first_name: "Marcus",
            last_name: "Williams",
            admin: false,
            status: 2,
            snap: "mwilliams_bjc",
            application_status: "Validated",
            personal_website: "https://mwilliamscs.com",
            education_level: 1,
            languages: ["English"],
            school: School.find_by(name: "Eastside Prep"),
            email: "mwilliams@eastsideprep.edu",
        },
        {
            first_name: "Aisha",
            last_name: "Patel",
            admin: false,
            status: 0,
            snap: "aisha_p",
            application_status: "Info Needed",
            personal_website: "https://aishapatel.dev",
            personal_email: "aisha.patel@yahoo.com",
            education_level: 2,
            more_info: "Currently setting up a new CS program at the college.",
            languages: ["English", "Hindi"],
            school: School.find_by(name: "Pacific Community College"),
            email: "apatel@pacificcc.edu",
        },
        {
            first_name: "Diego",
            last_name: "Morales",
            admin: false,
            status: 5,
            snap: "diego_teals",
            application_status: "Validated",
            personal_website: "https://dmorales-teals.com",
            personal_email: "diego.morales@proton.me",
            education_level: 1,
            languages: ["English", "Spanish"],
            school: School.find_by(name: "Lincoln High School"),
            email: "dmorales@lincolnhs.org",
        },
        {
            first_name: "Emily",
            last_name: "Nakamura",
            admin: false,
            status: 8,
            snap: "emily_nak",
            application_status: "Denied",
            personal_website: "https://nakamura-cs.net",
            education_level: 0,
            verification_notes: "Could not verify school affiliation.",
            languages: ["English", "Japanese"],
            school: School.find_by(name: "Riverside Middle School"),
            email: "enakamura@riverside-ms.edu",
        },
        {
            first_name: "Tariq",
            last_name: "Hassan",
            admin: false,
            status: 0,
            snap: "tariq_h",
            application_status: "Validated",
            personal_website: "https://tariqhassan.io",
            personal_email: "tariq.hassan@gmail.com",
            education_level: 1,
            languages: ["English", "Arabic"],
            school: School.find_by(name: "Eastside Prep"),
            email: "thassan@eastsideprep.edu",
        },
        {
            first_name: "Rachel",
            last_name: "Novak",
            admin: false,
            status: 0,
            snap: "rnovak_cs",
            application_status: "Validated",
            personal_website: "https://rachelnovak.dev",
            personal_email: "rachel.novak@gmail.com",
            education_level: 1,
            languages: ["English", "Czech"],
            school: School.find_by(name: "Lincoln High School"),
            email: "rnovak@lincolnhs.org",
        },
        {
            first_name: "Kevin",
            last_name: "Tran",
            admin: false,
            status: 1,
            snap: "kevtran_bjc",
            application_status: "Not Reviewed",
            personal_website: "https://kevintran.me",
            education_level: 2,
            languages: ["English", "Vietnamese"],
            school: School.find_by(name: "Pacific Community College"),
            email: "ktran@pacificcc.edu",
        },
        {
            first_name: "Fatima",
            last_name: "Al-Rashid",
            admin: false,
            status: 7,
            snap: "fatima_excite",
            application_status: "Validated",
            personal_website: "https://fatimaalrashid.org",
            personal_email: "fatima.alrashid@icloud.com",
            education_level: 1,
            languages: ["English", "Arabic", "French"],
            school: School.find_by(name: "Greenfield Charter Academy"),
            email: "falrashid@greenfieldcharter.org",
        },
        {
            first_name: "Mia",
            last_name: "Johansson",
            admin: false,
            status: 0,
            snap: "mia_johan",
            application_status: "Validated",
            personal_website: "https://miajohansson.se",
            personal_email: "mia.johansson@hotmail.com",
            education_level: 1,
            languages: ["English", "Swedish"],
            school: School.find_by(name: "Eastside Prep"),
            email: "mjohansson@eastsideprep.edu",
        },
    ]
  end

  def self.email_addresses
    [
      {
        email: "ball@berkeley.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Michael"),
      },
      {
        email: "lmock@berkeley.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Lauren"),
      },
      {
        email: "ball2@berkeley.edu",
        primary: false,
        teacher: Teacher.find_by(first_name: "Michael"),
      },
      {
        email: "ball3@berkeley.edu",
        primary: false,
        teacher: Teacher.find_by(first_name: "Michael"),
      },
      {
        email: "lmock2@berkeley.edu",
        primary: false,
        teacher: Teacher.find_by(first_name: "Lauren"),
      },
      {
        email: "pramirez@lincolnhs.org",
        primary: true,
        teacher: Teacher.find_by(first_name: "Priya"),
      },
      {
        email: "priya.ramirez@gmail.com",
        primary: false,
        teacher: Teacher.find_by(first_name: "Priya"),
      },
      {
        email: "jokonkwo@riverside-ms.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "James"),
      },
      {
        email: "james.okonkwo@outlook.com",
        primary: false,
        teacher: Teacher.find_by(first_name: "James"),
      },
      {
        email: "schen@greenfieldcharter.org",
        primary: true,
        teacher: Teacher.find_by(first_name: "Sofia"),
      },
      {
        email: "mwilliams@eastsideprep.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Marcus"),
      },
      {
        email: "apatel@pacificcc.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Aisha"),
      },
      {
        email: "aisha.patel@yahoo.com",
        primary: false,
        teacher: Teacher.find_by(first_name: "Aisha"),
      },
      {
        email: "dmorales@lincolnhs.org",
        primary: true,
        teacher: Teacher.find_by(first_name: "Diego"),
      },
      {
        email: "diego.morales@proton.me",
        primary: false,
        teacher: Teacher.find_by(first_name: "Diego"),
      },
      {
        email: "enakamura@riverside-ms.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Emily"),
      },
      {
        email: "thassan@eastsideprep.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Tariq"),
      },
      {
        email: "tariq.hassan@gmail.com",
        primary: false,
        teacher: Teacher.find_by(first_name: "Tariq"),
      },
      {
        email: "rnovak@lincolnhs.org",
        primary: true,
        teacher: Teacher.find_by(first_name: "Rachel"),
      },
      {
        email: "rachel.novak@gmail.com",
        primary: false,
        teacher: Teacher.find_by(first_name: "Rachel"),
      },
      {
        email: "ktran@pacificcc.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Kevin"),
      },
      {
        email: "falrashid@greenfieldcharter.org",
        primary: true,
        teacher: Teacher.find_by(first_name: "Fatima"),
      },
      {
        email: "fatima.alrashid@icloud.com",
        primary: false,
        teacher: Teacher.find_by(first_name: "Fatima"),
      },
      {
        email: "oburke@riverside-ms.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Owen"),
      },
      {
        email: "mjohansson@eastsideprep.edu",
        primary: true,
        teacher: Teacher.find_by(first_name: "Mia"),
      },
      {
        email: "mia.johansson@hotmail.com",
        primary: false,
        teacher: Teacher.find_by(first_name: "Mia"),
      },
    ]
  end
end
