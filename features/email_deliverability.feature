Feature: Teacher email deliverability reporting

  As an admin
  So that I can stop sending to bad teacher addresses
  I want to review teachers with deliverability issues

  Background: Teachers and email delivery issues exist
    Given the following schools exist:
    |       name            |     country     |     city     |  state  |            website            |
    |   UC Berkeley         |       US        |   Berkeley   |   CA    |   https://www.berkeley.edu    |
    Given the following teachers exist:
    | first_name | last_name  | admin | primary_email               | school      | application_status |
    | Admin      | User       | true  | testadminuser@berkeley.edu  | UC Berkeley | Validated          |
    | Delivery   | Problem    | false | delivery_problem@teacher.edu | UC Berkeley | Validated          |
    | Delivery   | Healthy    | false | delivery_healthy@teacher.edu | UC Berkeley | Validated          |
    Given the following email deliverability states exist:
    | email                        | emails_sent | emails_delivered | suppressed_at         | suppression_reason | last_delivery_event_type |
    | delivery_problem@teacher.edu | 3           | 0                | 2026-04-18 12:00:00   | hard_bounce        | bounce                   |

  Scenario: Admin can review teacher deliverability issues
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    When I go to the teachers page
    And I follow "Deliverability Issues"
    Then I should see "Teacher Deliverability Issues"
    And I should see "Delivery Problem"
    And I should see "delivery_problem@teacher.edu"
    And I should see "Suppressed (hard bounce)"
    And I should not see "delivery_healthy@teacher.edu"