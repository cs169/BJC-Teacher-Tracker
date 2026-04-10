Feature: DataTables sort indicators
  As an admin
  So that I can tell which column is sorted and in which direction
  Table headers show sort indicator arrows and a pointer cursor

  Background:
    Given the following schools exist:
      | name        | country | city     | state | website                  | grade_level | school_type |
      | UC Berkeley | US      | Berkeley | CA    | https://www.berkeley.edu | university  | public      |
    And the following teachers exist:
      | first_name | last_name | admin | primary_email              | school      | application_status |
      | Admin      | User      | true  | testadminuser@berkeley.edu | UC Berkeley | Validated          |
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google

  Scenario: Teachers table headers show sort indicators and pointer cursor
    When I go to the teachers page
    Then sortable table headers should have sort indicators
    And sortable table headers should have a pointer cursor
