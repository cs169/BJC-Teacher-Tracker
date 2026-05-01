Feature: Admin Data Tables functionality

  As an admin
  So that I can see how many people are teaching BJC
  I can use interactive datatables

  Background: Has an Admin in DB
    Given the following teachers exist:
      | first_name | last_name | admin | primary_email |
      | Admin | User | true | testadminuser@berkeley.edu |

  Scenario: Updating application status persists changes in database
    Given the following schools exist:
      | name | country | city | state | website | grade_level | school_type |
      | UC Berkeley | US | Berkeley | CA | https://www.berkeley.edu | university | public |
    Given the following teachers exist:
      | first_name | last_name  | admin | primary_email | school | snap | application_status |
      | Bobby | John | false | testteacher@berkeley.edu | UC Berkeley | bobby | not_reviewed |
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    # When I go to the teachers page
    And I go to the edit page for Bobby John
    And I set my application status as "Validated"
    And I press "Update"
    Then I see a confirmation "Saved"
    When I go to the teachers page
    And I check "Validated"
    Then I should see "Bobby John"

  Scenario: Show hidden results notice when searching with an active status filter
    Given the following schools exist:
      | name        | country | city     | state | website                  | grade_level | school_type |
      | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    Given the following teachers exist:
      | first_name | last_name  | admin | primary_email             | school      | application_status |
      | Victor     | Validateme | false | testteacher1@berkeley.edu | UC Berkeley | Validated          |
      | Danny      | Denyme     | false | testteacher2@berkeley.edu | UC Berkeley | Denied             |
      | Peter      | Pendme     | false | testteacher3@berkeley.edu | UC Berkeley | Not Reviewed       |
    Given I am on the BJC home page
    Given I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    And   I fill in the teachers table search with "me"
    Then  I should see "1 result(s) in Denied, 1 result(s) in Not Reviewed — hidden by current filter"
    And   I check "Denied"
    Then  I should see "1 result(s) in Not Reviewed — hidden by current filter"
    And   I check "Not Reviewed"
    Then  I should not see "hidden by current filter"

  Scenario: Filter all teacher info as an admin
    Given the following schools exist:
      | name        |     country     | city     | state | website                  | grade_level | school_type |
      | UC Berkeley |       US        | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    Given the following teachers exist:
      | first_name | last_name  | admin | primary_email             | school      | application_status |
      | Victor     | Validateme | false | testteacher1@berkeley.edu | UC Berkeley |      Validated     |
      | Danny      | Denyme     | false | testteacher2@berkeley.edu | UC Berkeley |       Denied       |
      | Peter      | Pendme     | false | testteacher3@berkeley.edu | UC Berkeley |     Not Reviewed   |
    Given I am on the BJC home page
    Given I have an admin email
    And   I follow "Log In"
    Then  I can log in with Google
    When  I go to the teachers page
    And   I check "Not Reviewed"
    And   I uncheck "Validated"
    Then  I should see "Peter"
    Then  I should not see "Victor"
    Then  I should not see "Danny"
    And   I check "Validated"
    Then  I should see "Peter"
    Then  I should see "Victor"
    Then  I should not see "Danny"
