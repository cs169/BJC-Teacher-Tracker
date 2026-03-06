Feature: Managing personal email addresses for teachers

  Background:
  Background: Has an Admin in DB
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email            |
      | Admin    | User    | true  | testadminuser@berkeley.edu   |
    Given the following schools exist:
      |       name      |     country     |     city     |  state  |            website            |  grade_level  |  school_type  |
      |   UC Berkeley   |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |  university   |     public    |
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email            | school      | snap   | application_status |
      | Joseph     | Mamoa     | false | jose.primary@email.com | UC Berkeley | false |    Validated       |
    Given the following emails exist:
      | first_name | last_name | email                    | primary |
      | Joseph     | Mamoa     | jose.personal1@email.com | false   |
      | Joseph     | Mamoa     | jose.personal2@email.com | false   |


  Scenario: Admin views teacher personal emails
    Given I am on the BJC home page
    And I have an admin email
    And   I follow "Log In"
    Then I can log in with Google
    When I follow "Teachers"
    And I follow "Joseph Mamoa"
    Then I should see "Admin View Joseph Mamoa"
    Then I should see "jose.personal1@email.com"
    Then I should see "jose.personal2@email.com"
    Then I should see "Edit Personal Emails"

  Scenario: Admin adds a personal email address via modal
    Given I am on the BJC home page
    And I have an admin email
    And   I follow "Log In"
    Then I can log in with Google
    When I follow "Teachers"
    And I follow "Joseph Mamoa"
    And I click "Edit Personal Emails" to open the email modal
    And I add "jose.personal3@email.com" to the email input
    Then I should see "jose.personal3@email.com" in the email tags
    And I press "Add Emails"
    Then I should see a "info" flash message "Personal email addresses added successfully."
    Then I should see "Admin View Joseph Mamoa"
    Then I should see "jose.personal3@email.com"

  Scenario: Admin removes email tag from modal before submitting
    Given I am on the BJC home page
    And I have an admin email
    And   I follow "Log In"
    Then I can log in with Google
    When I follow "Teachers"
    And I follow "Joseph Mamoa"
    And I click "Edit Personal Emails" to open the email modal
    And I add "jose.personal3@email.com" to the email input
    And I add "jose.personal4@email.com" to the email input
    Then I should see "jose.personal3@email.com" in the email tags
    Then I should see "jose.personal4@email.com" in the email tags
    And I remove "jose.personal3@email.com" from the email input
    Then I should not see "jose.personal3@email.com" in the email tags
    And I press "Add Emails"
    Then I should see a "info" flash message "Personal email addresses added successfully."
    Then I should see "jose.personal4@email.com"
    Then I should not see "jose.personal3@email.com"

  Scenario: Admin deletes a personal email via red X on teacher page
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I follow "Teachers"
    And I follow "Joseph Mamoa"
    Then I should see "jose.personal1@email.com"
    When I click the delete button for email "jose.personal1@email.com"
    Then I should see a "info" flash message "Email address deleted successfully."
    Then I should not see "jose.personal1@email.com"
    And I should see "jose.personal2@email.com"

  Scenario: Admin tries to add a duplicate email via modal
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I follow "Teachers"
    And I follow "Joseph Mamoa"
    And I click "Edit Personal Emails" to open the email modal
    And I add "jose.personal1@email.com" to the email input
    And I press "Add Emails"
    Then I should see a "danger" flash message "Email has already been taken"

  Scenario: Admin tries to add an email that exists for another teacher via modal
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I follow "Teachers"
    And I follow "Joseph Mamoa"
    And I click "Edit Personal Emails" to open the email modal
    And I add "testadminuser@berkeley.edu" to the email input
    And I press "Add Emails"
    Then I should see a "danger" flash message "Email has already been taken"

  Scenario: Admin closes email modal without adding
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I follow "Teachers"
    And I follow "Joseph Mamoa"
    And I click "Edit Personal Emails" to open the email modal
    And I add "jose.shouldnotexist@email.com" to the email input
    And I close the email modal
    Then I should not see "jose.shouldnotexist@email.com"
