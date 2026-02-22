Feature: basic admin functionality

  As an admin
  So that I can see how many people are teaching BJC
  I can login in an see the dashboard

  Background: Has an Admin in DB
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email            |
      | Admin    | User    | true  | testadminuser@berkeley.edu   |

  Scenario: Logging in as an admin
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    And I should see "BJC Teacher Dashboard"

  Scenario: Logging out as an admin
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    And I follow "Logout"
    Then I should see "Request Access to BJC Teacher Materials"
    Then I should see "Log In"

  Scenario: Viewing Teachers as an admin
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    Then I should see "BJC Teachers"

# TODO: Add steps to check basic dashboard functions
# A search field should be visible on the index pages
# Check for a CSV button

# TODO: Checks for validation and deny belong here.

  Scenario: Logging in with non-admin, unregistered Google Account should fail
    Given I have a non-admin, unregistered Google email
    Given I am on the BJC home page
    And I follow "Log In"
    Then I can log in with Google
    And I should see "Please submit a new request."

  Scenario: Logging in with non-admin, unregistered Microsoft Account should fail
    Given I have a non-admin, unregistered Microsoft email
    Given I am on the BJC home page
    And I follow "Log In"
    Then I can log in with Microsoft
    And I should see "Please submit a new request."

  Scenario: Logging in with non-admin, unregistered Snap Account should fail
    Given I have a non-admin, unregistered Snap email
    Given I am on the BJC home page
    And I follow "Log In"
    Then I can log in with Snap
    And I should see "Please submit a new request."

  Scenario: Logging in with non-admin, unregistered Clever Account should fail
    Given I have a non-admin, unregistered Clever email
    Given I am on the BJC home page
    And I follow "Log In"
    Then I can log in with Clever
    And I should see "Please submit a new request."

  Scenario: Non-admin, unregistered user should not be able to see admin-only pages
    Given I have a non-admin, unregistered Google email
    Given I am on the BJC home page
    When  I go to the dashboard page
    Then  I should see "Only admins can access this page"
    And   I should be on the new teachers page

  Scenario: Edit teacher info as an admin
    Given the following schools exist:
      |       name      |     country     |     city     |  state  |            website            |  grade_level  |  school_type  |
      |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |  university   |     public    |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email            | school      | snap   |
      | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley | alonzo |
    Given I am on the BJC home page
    Given I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    When  I go to the edit page for Joseph Mamoa
    Then  I should see "Joseph"
    And   I enter my "First Name" as "Joe"
    And   I set my status as "Other - Please specify below."
    And   I set my education level target as "College"
    And   I press "Update"
    Then I see a confirmation "Saved"

  Scenario: Teacher info displays alphabetically ordered comma separated classroom languages
  Given the following schools exist:
  |       name            |     country     |     city     |  state  |            website            |
  |   UC Berkeley         |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      | languages                      |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley | - English\n- French\n- Spanish |
  Given I am on the BJC home page
  And I have an admin email
  And I follow "Log In"
  Then I can log in with Google
  When I go to the show page for Joseph Mamoa
  Then I should see "English, French, Spanish"

  Scenario: Adding/removing classroom languages in arbitrary order still displays alphabetically sorted
  Given the following schools exist:
  |       name            |     country     |     city     |  state  |            website            |
  |   UC Berkeley         |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
  Given the following teachers exist:
  | first_name | last_name | admin | primary_email            | school      | languages |
  | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley | - English\n- Hindi |
  Given I am on the BJC home page
  And I have an admin email
  And I follow "Log In"
  Then I can log in with Google
  When I go to the edit page for Joseph Mamoa
  And  I select "Spanish" from the languages dropdown
  And  I select "French" from the languages dropdown
  And I select "German" from the languages dropdown
  And I remove "English" from the languages dropdown
  And I remove "Hindi" from the languages dropdown
  And I press "Update"
  And I go to the show page for Joseph Mamoa
  Then I should see "French, German, Spanish"

  Scenario: Changing application status as admin sends emails
    Given the following schools exist:
      |       name      |     country     |     city     |  state  |            website            |  grade_level  |  school_type  |
      |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |  university   |     public    |
    Given the following teachers exist:
      | first_name | last_name  | admin | primary_email            | school      | snap   | application_status |
      | Bobby      | John       | false | testteacher@berkeley.edu | UC Berkeley | bobby  | denied             |
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    And I go to the edit page for Bobby John
    And I set my application status as "Info Needed"
    And I set my request reason as "Test123"
    And I press "Update"
    Then I see a confirmation "Saved"
    And I send a request info email with content "Test123"
    When I go to the edit page for Bobby John
    And I set my application status as "Validated"
    And I press "Update"
    Then I see a confirmation "Saved"
    And I send a welcome email
    When I go to the edit page for Bobby John
    And I set my application status as "Denied"
    And I press "Update"
    Then I see a confirmation "Saved"
    And I send a deny email
    When I go to the edit page for Bobby John
    And I set my application status as "Validated"
    And I select "Yes" from the skip email notification dropdown
    And I press "Update"
    Then I see a confirmation "Saved"
    And my most recent email did not have subject line "Welcome Email"

  Scenario: Updating without changing application status does not send email
    Given the following schools exist:
      |       name      |     country     |     city     |  state  |            website            |  grade_level  |  school_type  |
      |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |  university   |     public    |
    Given the following teachers exist:
      | first_name | last_name  | admin | primary_email            | school      | snap   | application_status |
      | Bobby      | John       | false | testteacher@berkeley.edu | UC Berkeley | bobby  | denied             |
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    And I go to the edit page for Bobby John
    And I set my application status as "Denied"
    And I set my request reason as "Test123"
    And I press "Update"
    Then I should not have sent out any emails

  Scenario: Deny teacher as an admin
    Given the following schools exist:
      | name        |     country     | city     | state | website                  | grade_level | school_type |
      | UC Berkeley |       US        | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email            | school      |
      | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
    Given I am on the BJC home page
    Given I have an admin email
    When  I follow "Log In"
    Then  I can log in with Google
    And   I press "❌" within "#DataTables_Table_0 > tbody > tr:nth-child(1)"
    Then  I should see "Reason"
    And   I should see "Deny Joseph Mamoa"
    And   I fill in "denial_reason" with "Test"
    And   I press "Cancel"
    And   I press "❌" within "#DataTables_Table_0 > tbody > tr:nth-child(1)"
    Then  the "denial_reason" field should not contain "Test"
    And   I fill in "denial_reason" with "Denial Reason"
    And   I press "Submit"
    Then  I send a deny email

  Scenario: Not logged in should not have access to edit
    Given the following schools exist:
      | name        |     country     | city     | state | website                  | grade_level | school_type |
      | UC Berkeley |       US        | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email            | school      |
      | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
    When  I go to the edit page for Joseph Mamoa
    Then  should see "You need to log in to access this."

  Scenario: View teacher info as an admin
    Given the following schools exist:
      | name        |     country     | city     | state | website                  | grade_level | school_type |
      | UC Berkeley |       US        | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email           | school      | snap   |
      | Joseph     | Test     | false | testteacher@berkeley.edu | UC Berkeley | alonzo |
    Given I am on the BJC home page
    Given I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    And   I uncheck "Validated"
    When  I follow "Joseph Test"
    Then  I should see "Joseph Test"
    And   I should see "Edit Information"
    And   I should see "School"
    And   I should see "School Location"
    And   I should see "Email"
    And   I should see "Personal or Course Website"

  Scenario: Admin can see verification notes on teacher profile
    Given the following schools exist:
      | name        |     country     | city     | state | website                  | grade_level | school_type |
      | UC Berkeley |       US        | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email             | school      | snap   | verification_notes                                 |
      | Joseph     | Test      | false | testteacher@berkeley.edu  | UC Berkeley | alonzo | Principal contact: principal@berkeley.edu         |
    Given I am on the BJC home page
    Given I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    When  I follow "Joseph Test"
    Then  I should see "Verification Notes"
    And   I should see "Principal contact: principal@berkeley.edu"

  Scenario: Edit teacher info as an admin navigating from view only page to edit page
    Given the following schools exist:
      |       name      |     country     |     city     |  state  |            website            |  grade_level  |  school_type  |
      |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |  university   |     public    |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email               | school      | snap   |
      | Joseph     | Mamoa New    | false | testteacher@berkeley.edu | UC Berkeley | alonzo |
    Given I am on the BJC home page
    Given I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    And   I uncheck "Validated"
    When  I follow "Joseph Mamoa New"
    Then  I should see "Joseph Mamoa"
    And   I should see "Edit Information"
    And   I follow "Edit Information"
    And   I should see "Joseph"
    And   I enter my "First Name" as "Joe"
    And   I set my status as "Other - Please specify below."
    And   I set my education level target as "College"
    And   I press "Update"
    Then  I see a confirmation "Saved"

  Scenario: Should be able to resend welcome email
    Given the following schools exist:
      |       name      |     country     |     city     |  state  |            website            |  grade_level  |  school_type  |
      |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |  university   |     public    |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email            | school      | snap   | application_status |
      | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley | alonzo | validated |
    Given I am on the BJC home page
    Given I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    When  I go to the edit page for Joseph Mamoa
    Then I should see a button named "Resend Welcome Email"

  Scenario: Admin can access new teacher button at teacher index page
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    And I should see "BJC Teacher Dashboard"
    Given I follow "Teachers"
    Then I should see "BJC Teachers"
    And I press "New Teacher"
    Then I should see "Request Access to BJC Teacher Materials"

  Scenario: Admin can access new school button at teacher index page
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    And I should see "BJC Teacher Dashboard"
    Given I follow "Schools"
    Then I should see "BJC Schools"
    And I press "New School"
    Then I should see "Add a School"

  Scenario: Request information from a teacher as an admin
    Given the following schools exist:
      | name        |     country     | city     | state | website                  | grade_level | school_type |
      | UC Berkeley |       US        | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name | last_name | admin | primary_email            | school      |
      | Joseph     | Mamoa     | false | testteacher@berkeley.edu | UC Berkeley |
    And I am on the BJC home page
    And I have an admin email
    When I follow "Log In"
    Then I can log in with Google
    And I press "❓" within "#DataTables_Table_0 > tbody > tr:nth-child(1)"
    Then I should see "Reason"
    And I should see "Request Info from Joseph Mamoa"
    And I fill in "request_reason" with "Need more details on qualifications"
    And I press "Cancel"
    And I press "❓" within "#DataTables_Table_0 > tbody > tr:nth-child(1)"
    Then the "request_reason" field should not contain "Need more details on qualifications"
    And I fill in "request_reason" with "Complete your profile details"
    And I press "Submit"
    Then I send a request info email

  Scenario: Admin update info without mandatory field shows error
    Given the following schools exist:
      | name        | country | city     | state | website                  | grade_level | school_type |
      | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name | last_name | admin | primary_email            | school      |
      | Jane       | Doe       | false | janedoe@berkeley.edu     | UC Berkeley |
    Given I am on the BJC home page
    And   I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    And   I go to the edit page for Jane Doe
    And   I fill in "School Email" with ""
    And   I press "Update"
    Then  I should be on the edit page for Jane Doe

  Scenario: Admin can switch merge order
    Given the following schools exist:
     | name        | country | city     | state | website                  | grade_level | school_type |
     | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name | last_name  | admin  | primary_email              | primary_email     | school      |
      | Jane       | Doe        | false  | janedoe@berkeley.edu       |  jd@berkeley.edu  | UC Berkeley |
      | Bobby       | John       | false | bobbyjohn@berkeley.edu     |  bj@berkeley.edu  | UC Berkeley |
    Given I am on the BJC home page
    And   I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    And I go to the merge preview page for Jane into Bobby
    Then I should see "Preview Merge of Jane Doe into Bobby John"
    When I follow "Switch Merge Order"
    Then I should see "Preview Merge of Bobby John into Jane Doe"

  Scenario: Merging teachers only updates blank fields with those of teacher being merged
    Given the following schools exist:
     | name        | country | city     | state | website                  | grade_level | school_type |
     | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name     | last_name   | personal_website  | admin  | primary_email              |  school      | application_status |
      | Jane           |  Doe        | abc@berkeley.edu  | false  | janedoe@berkeley.edu       |  UC Berkeley | validated          |
      | Bobby          |  John       |                   | false  | bobbyjohn@berkeley.edu     | UC Berkeley  | denied             |
    Given I am on the BJC home page
    And   I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When I go to the merge preview page for Jane into Bobby
    And I follow "Confirm Merge"
    Then I see a confirmation "Teachers merged successfully"
    And the following entries should not exist in the teachers database:
      | first_name     | last_name   | personal_website           | admin  | primary_email              | school      | application_status |
      | Jane           |  Doe        | https://abc.berkeley.edu   | false  | janedoe@berkeley.edu       | UC Berkeley | validated          |
      | Bobby          |  John       |                            | false  | bobbyjohn@berkeley.edu     | UC Berkeley | denied             |
    And the following entries should exist in the teachers database:
      | first_name     | last_name       | personal_website  | admin  | primary_email              | school       | application_status |
      | Bobby          |  John           | abc@berkeley.edu  | false  | bobbyjohn@berkeley.edu     | UC Berkeley  | denied             |

  Scenario: Merging teachers sums session counts, concatenates IP histories, and saves most recent datetime
    Given the following schools exist:
     | name        | country | city     | state | website                  | grade_level | school_type |
     | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name     | last_name   | session_count | ip_history             |   last_session_at      |   admin   | primary_email                        | school      |
      | Jane           |  Doe        |  169          | 1.2.3.4, 4.5.6.7       |   2023-04-10 12:30:00  |    false  | janedoe@berkeley.edu         | UC Berkeley |
      | Bobby          |  John       |  365          |  4.5.6.7, 7.8.9.10     |   2023-01-11 12:00:00  |    false  | bobbyjohn@berkeley.edu       | UC Berkeley |
    Given I am on the BJC home page
    And   I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When I go to the merge preview page for Jane into Bobby
    And I follow "Confirm Merge"
    Then I see a confirmation "Teachers merged successfully"
    And the following entries should exist in the teachers database:
    | first_name     | last_name    | session_count | ip_history                   |   last_session_at      |    admin  | primary_email               | school      |
    | Bobby          |  John        |  534          | 1.2.3.4, 4.5.6.7, 7.8.9.10   |    2023-04-10 12:30:00 |    false  | bobbyjohn@berkeley.edu       | UC Berkeley |

  Scenario: Admin can access merge page from teacher show page
    Given the following schools exist:
     | name        | country | city     | state | website                  | grade_level | school_type |
     | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name | last_name  | admin  | primary_email              |  school      |
      | Jane       | Doe        | false  | janedoe@berkeley.edu       | UC Berkeley  |
      | Bobby      | John       | false  | bobbyjohn@berkeley.edu     |  UC Berkeley |
    Given I am on the BJC home page
    And   I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the show page for Bobby John
    And   I press "Merge"
    Then I should see "Choose A User To Merge Into"
    When I follow the first "Jane Doe" link
    Then I should be on the merge preview page for Bobby into Jane

  Scenario: Admin does not see uploaded files for teachers with non-homeschool status
    Given the following schools exist:
     | name        | country | city     | state | website                  | grade_level | school_type |
     | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name | last_name  | admin  | primary_email              |  school      | status                                                  |
      | Jane       | Doe        | false  | janedoe@berkeley.edu       | UC Berkeley  | I am using BJC as a resource, but not teaching with it. |
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the show page for Jane Doe
    Then I should not see "Supporting Files:"
    When I go to the edit page for Jane Doe
    Then I should not see "Supporting Files:"
    And I should not see "Upload More Files:"

  Scenario: Admin can edit files of a homeschool teacher on the teacher's show page
    Given the following schools exist:
     | name        | country | city     | state | website                  | grade_level | school_type |
     | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name | last_name  | admin  | primary_email              |  school      |
      | Jane       | Doe        | false  | janedoe@berkeley.edu       | UC Berkeley  |
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    Then I go to the edit page for Jane Doe
    And I set my status as "I am teaching homeschool with the BJC curriculum."
    And I press "Update"
    Then I go to the show page for Jane Doe
    When I attach the file with name "test_file.txt" on the show page
    Then I see a confirmation "File was successfully uploaded"
    When I click the first file deletion button
    And I accept the popup alert
    Then I see a confirmation "File was successfully removed"

# Scenario: Admin can import csv file. The loader should filter invalid record and create associate school.
#  Given the following schools exist:
#  |       name      |     country     |     city     |  state  |            website            |
#  |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://bjc.berkeley.edu    |
#  Given I am on the BJC home page
#  Given I have an admin email
#  And I follow "Log In"
#  Then I can log in with Google
#  And I should see "BJC Teacher Dashboard"
#  Given I follow "Teachers"
#  And I uncheck "Validated"
#  And I press "Upload CSV"
#  Then The "#hidden_file_select_input" form is invalid
#  Then I attach the csv "features/test_utils/test_teacher_first.csv"
#  Then I should see "ank sha"
#  Then I should not see "Steve Gao"
#  Then I should not see "Haha He"
#  Then I should see "Wuho He"
#  Then I should see "Successfully created/updated 2 teachers"
#  Then I should see "1 schools has been created"
#  Then I should see "2 teachers has failed with following emails: [ steve.gao02112@gmail.com ] [ steve.fdso02112@gmail.com ]"
#  Then I follow "Schools"
#  Then I should see "uci"
#  Then I follow "Teachers"
#  Then I attach the csv "features/test_utils/test_teacher_second.csv"
#  Then I should see "anke sha"
#  Then I should see "Steve He"
#  Then I should see "Successfully created/updated 2 teachers"
#  Then I should see "2 teachers has failed with following emails: [ 1@gmail.com ] [ 2@gmail.com ]"

# Scenario: Importing with new schools model fields works
#  Given the following schools exist:
#  |       name    |     country     |     city     |  state  |            website            |
#  | UC Berkeley   |       US        |   Berkeley   |   CA    |   https://bjc.berkeley.edu    |
#  Given I am on the BJC home page
#  Given I have an admin email
#  And I follow "Log In"
#  Then I can log in with Google
#  And I should see "BJC Teacher Dashboard"
#  Given I follow "Teachers"
#  And I uncheck "Validated"
#  And I press "Upload CSV"
#  Then The "#hidden_file_select_input" form is invalid
#  Then I attach the csv "features/test_utils/test_teacher_third.csv"
#  Then I should see "ank sha"
#  Then I should not see "Steve Gao"
#  Then I should not see "Haha He"
#  Then I should see "Wuho He"
#  Then I should see "Successfully created/updated 2 teachers"
#  Then I should see "1 schools has been created"
#  Then I should see "2 teachers has failed with following emails: [ steve.gao02112@gmail.com ] [ steve.fdso02112@gmail.com ]"
