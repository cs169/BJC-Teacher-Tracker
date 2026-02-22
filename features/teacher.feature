Feature: teacher login functionality

    As a teacher who has an application
    So that I can edit my information
    I can login via gmail

Scenario: Logging in failure redirects to new teachers page
  Given I am on the BJC home page
  Given I have a teacher Google email
  And   I follow "Log In"
  And   I cannot log in with Google
  Then  I should be on the new teachers page

Scenario: Logging in as a teacher
  Given I am on the BJC home page
  Given I have a teacher Google email
  And   I follow "Log In"
  Then  I should see "Sign in with Google"
  And   I should see "Sign in with Snap"
  And   I should see "Sign in with Microsoft"
  And   I should see "Sign in with Clever"
  Then  the page should be axe clean

Scenario: Logging in as a teacher with Google account should be able to edit their info
  Given the following schools exist:
  |       name            |     country     |     city     |  state  |            website            |
  |   UC Berkeley         |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  | Cupertino High School |       US        |   Cupertino  |   CA    |      https://chs.fuhsd.org    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And   I follow "Log In"
  Then  I can log in with Google
  And   I see a confirmation "You may update your information"
  Then  the "First Name" field should contain "Joseph"
  And   I enter my "First Name" as "Joe"
  And   I set my status as "I am a TEALS volunteer, and am teaching the BJC curriculum."
  And   I set my education level target as "College"
  And   I fill in the school name selectize box with "Cupertino High School, Cupertino, CA" and choose to add a new school
  And   I select "United States" from "Country"
  And   I enter my "City" as "Cupertino"
  And   I select "CA" from "State" dropdown
  And   I enter my "School Website" as "https://chs.fuhsd.org"
  And   I select "Spanish" from the languages dropdown
  And   I press "Update"
  Then  I see a confirmation "Successfully updated your information"
  Then  the "First Name" field should contain "Joe"
  And   the languages dropdown should have the option "Spanish" selected

Scenario: Logging in as a teacher with Microsoft account should be able to edit their info
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
  Given I have a teacher Microsoft email
  Given I am on the BJC home page
  And   I follow "Log In"
  Then  I can log in with Microsoft
  And   I see a confirmation "You may update your information"
  Then  the "First Name" field should contain "Joseph"

Scenario: Logging in as a teacher with Snap account should be able to edit their info
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
  Given I have a teacher Snap email
  Given I am on the BJC home page
  And   I follow "Log In"
  Then  I can log in with Snap
  And   I see a confirmation "You may update your information"
  Then  the "First Name" field should contain "Joseph"

  Scenario: Logging in as a teacher with Clever account should be able to edit their info
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
  Given I have a teacher Clever email
  Given I am on the BJC home page
  And   I follow "Log In"
  Then  I can log in with Clever
  And   I see a confirmation "You may update your information"
  Then  the "First Name" field should contain "Joseph"

Scenario: Logged in teacher with Not_Reviewed application status can update their info
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      | snap   |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley | alonzo |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And   I follow "Log In"
  Then  I can log in with Google
  And   I enter my "First Name" as "Joe"
  And   I enter my "Last Name" as "Mamoa"
  And   I enter my "Snap! Username" as "alonzo"
  And   I set my status as "I am teaching BJC as an AP CS Principles course."
  And   I set my education level target as "High School"
  And   I fill in the school name selectize box with "Cupertino High School" and choose to add a new school
  And   I select "United States" from "Country"
  And   I enter my "City" as "Cupertino"
  And   I select "CA" from "State" dropdown
  And   I enter my "School Website" as "https://chs.fuhsd.org"
  And   I select "High School" from "Grade Level"
  And   I select "Public" from "School Type"
  And   I press "Update"
  Then  I see a confirmation "Successfully updated your information"
  And   I am on the edit page for Joe Mamoa

  Scenario: Logged in teacher with not_reviewed status cannot change Snap from new form path
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      | snap   |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley | alonzo |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And   I follow "Log In"
  Then  I can log in with Google
  And   I enter my "First Name" as "Joe"
  And   I enter my "Last Name" as "Mamoa"
  And   I enter my "School Email" as "testteacher@berkeley.edu"
  And   I enter my "Snap! Username" as "not_alonzo"
  And   I set my status as "I am teaching BJC as an AP CS Principles course."
  And   I set my education level target as "High School"
  And   I fill in the school name selectize box with "Cupertino High School" and choose to add a new school
  And   I select "United States" from "Country"
  And   I enter my "City" as "Cupertino"
  And   I select "CA" from "State" dropdown
  And   I enter my "School Website" as "https://chs.fuhsd.org"
  And   I press "Update"
  And   I should see "Edit Joe Mamoa"
  And   the "Snap! Username" field should contain "alonzo"

Scenario: Homeschool teacher can add/view supporting files
  Given I have a teacher Google email
  And the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  And the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
  And I am on the BJC home page
  And I follow "Log In"
  Then  I can log in with Google
  When I set my status as "I am teaching homeschool with the BJC curriculum."
  Then I should see "No files attached yet."
  When I attach the file with name "test_file.txt"
  And I press "Update"
  And I follow "test_file.txt"
  Then I should see "test_file.txt"
  When I attach the file with name "test_file2.txt"
  And I press "Update"
  Then I should see "test_file.txt"
  And I should see "test_file2.txt"

Scenario: Logged in teacher can only edit their own information
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu  |
  | Jane       | Austin    | false | testteacher2@berkeley.edu |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  Then I should see "You can only edit your own information"

Scenario: Logging in as a teacher with not_reviewed status should see "Update" instead of "Submit" when editing info
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu  |
  Given I have a teacher Google email
  Given I am on the BJC home page
  Then I should see a button named "Submit"
  Given I follow "Log In"
  Then I can log in with Google
  Then I should see a button named "Update"

Scenario: Frontend should not allow Teacher to edit their email
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  And  I enter my "School Email" as "wrong@berkeley.edu"
  And I press "Update"
  Then the "School Email" field should contain "testteacher@berkeley.edu"
  Then the "Snap!" field should contain "Jane"

Scenario: Validated teacher should see resend button
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap | application_status |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane | validated          |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  Then I should see a button named "Resend Welcome Email"

Scenario: teacher with not_reviewed status should not see resend button
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap | application_status |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane | Not Reviewed       |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  Then I should not see "Resend Welcome Email"

Scenario: Denied teacher should not see resend button
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap | application_status |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane | denied |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  Then I should not see "Resend Welcome Email"

Scenario: Denied teacher cannot edit their information
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap | application_status | more_info |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane | denied | Original Information |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  And  I enter my "More Information" as "Updated information"
  And I press "Update"
  Then the "More Information" field should contain "Original Information"

Scenario: Validated teacher should not see Tags or NCES ID
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap | application_status |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane | validated          |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  Then I should not see "Tags"
  And I should not see "NCES ID"

Scenario: Teacher with not_reviewed status should not see Tags or NCES ID
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap | application_status |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane | Not Reviewed          |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  Then I should not see "Tags"
  And I should not see "NCES ID"

Scenario: Denied teacher should not see Tags or NCES ID
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | snap | application_status |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | Jane | denied |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  Then I should not see "Tags"
  And I should not see "NCES ID"

Scenario: Logged in teacher can save verification notes in profile form
  Given the following schools exist:
  |       name      |     country     |     city     |  state  |            website            |
  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email             | school      | snap |
  | Jane       | Austin    | false | testteacher@berkeley.edu  | UC Berkeley | Jane |
  Given I have a teacher Google email
  Given I am on the BJC home page
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Jane Austin
  And  I enter my "Verification Notes" as "Principal contact: principal@school.edu"
  And I press "Update"
  Then I see a confirmation "Successfully updated your information"
  And the "verification_notes" of the user with email "testteacher@berkeley.edu" should be "Principal contact: principal@school.edu"
