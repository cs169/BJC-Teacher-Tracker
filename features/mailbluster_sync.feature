Feature: MailBluster email sync

  As an admin
  So that I can keep teacher emails in sync with MailBluster
  I want to be able to sync teachers to MailBluster

  Background: Has an Admin and teachers in DB
    Given the following schools exist:
    |       name            |     country     |     city     |  state  |            website            |
    |   UC Berkeley         |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
    Given the following teachers exist:
    | first_name | last_name  | admin | primary_email              | school      | application_status |
    | Admin      | User       | true  | testadminuser@berkeley.edu | UC Berkeley | Validated          |
    | Mbluster   | Validated  | false | mb_validated@teacher.edu   | UC Berkeley | Validated          |
    | Mbluster   | Pending    | false | mb_pending@teacher.edu     | UC Berkeley | Not Reviewed       |

  Scenario: Admin sees MailBluster sync information on teacher show page
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    And I follow "Mbluster Validated"
    Then I should see "MailBluster Sync"
    And I should see "Not synced"
    And I should see a button named "Sync to MailBluster"

  Scenario: Admin sees Sync All button on teachers index page
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    Then I should see a button named "Sync All to MailBluster"

  Scenario: Admin does not see MB Sync column in teachers table
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    Then I should not see "MB Sync"
    And I should not see "Not Synced"

  Scenario: Admin sees email delivery stats on teacher show page
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    And I follow "Mbluster Validated"
    Then I should see "Sent: 0"
    And I should see "Delivered: 0"
    And I should see "Bounced: No"

  Scenario: Admin sees MailBluster section for pending teacher
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    And I check "Not Reviewed"
    And I follow "Mbluster Pending"
    Then I should see "MailBluster Sync"
    And I should see "Not synced"

  Scenario: Non-admin cannot see MailBluster sync controls
    Given I am on the BJC home page
    Given I have a non-admin, unregistered Google email
    And I follow "Log In"
    Then I can log in with Google
    Then I should not see "Sync All to MailBluster"
    And I should not see "MB Sync"
