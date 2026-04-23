Feature: Schools page uses server-side DataTables
  As an admin
  So that the schools page loads quickly with many records
  The table fetches data from the server via AJAX

  Background:
    Given the following schools exist:
      | name            | country | city      | state | website                    | grade_level | school_type |
      | UC Berkeley     | US      | Berkeley  | CA    | https://www.berkeley.edu   | university  | public      |
      | Stanford        | US      | Palo Alto | CA    | https://www.stanford.edu   | university  | private     |
      | MIT             | US      | Cambridge | MA    | https://www.mit.edu        | university  | private     |
    And the following teachers exist:
      | first_name | last_name | admin | primary_email              |
      | Admin      | User      | true  | testadminuser@berkeley.edu |
    Given I am on the BJC home page
    And I have an admin email
    And I follow "Log In"
    Then I can log in with Google

  Scenario: Schools page loads and displays data via server-side DataTables
    When I go to the schools page
    Then I should see "UC Berkeley"
    And I should see "Stanford"
    And I should see "MIT"

  Scenario: Searching filters school results
    When I go to the schools page
    And I search the schools table for "Berkeley"
    Then I should see "UC Berkeley"
    And I should not see "MIT"
