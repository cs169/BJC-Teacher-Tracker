# ============================================================================
# Cucumber feature: School Data Cleanup
# ============================================================================
#
# These scenarios exercise the two rake tasks in
# lib/tasks/school_data_cleanup.rake via end-to-end behavioral tests.
#
# Each scenario:
#   1. Creates test data (via FactoryBot in the step definitions).
#   2. Invokes a rake task with APPLY=true.
#   3. Reloads the record and asserts the expected outcome.
#
# Note: all data is created in the Rails test database and cleaned up
# by DatabaseCleaner between scenarios (configured in features/support/env.rb).
# ============================================================================

Feature: Fix school data
  As an administrator
  So that school records have accurate country and grade level information
  I can run rake tasks to detect and fix data gaps

  # --------------------------------------------------------------------------
  # Country fix scenarios
  # --------------------------------------------------------------------------

  Scenario: A school with no country and a valid US state gets fixed
    # A legacy school record has country=nil but state="CA".
    # The fix_countries task should infer country="US" from the state.
    Given a school "Berkeley Academy" exists with no country and state "CA"
    When I run the rake task "schools:fix_countries"
    Then the school "Berkeley Academy" should have country "US"

  Scenario: A school's country is inferred from its website TLD
    # A school with a .de (Germany) website and no state.
    # The task should set country="DE" based on the top-level domain.
    Given a school "Berlin Schule" exists with no country and website "https://www.schule.de"
    When I run the rake task "schools:fix_countries"
    Then the school "Berlin Schule" should have country "DE"

  Scenario: A school with a valid country is not modified
    # The task should leave already-correct records untouched.
    Given a school "UC Berkeley" exists with country "US"
    When I run the rake task "schools:fix_countries"
    Then the school "UC Berkeley" should have country "US"

  Scenario: A school that cannot be fixed is left unchanged
    # A school with a .com website, no state, and no coordinates.
    # None of the heuristics can determine the country.
    Given a school "Mystery Academy" exists with no country and website "https://mystery.com"
    When I run the rake task "schools:fix_countries"
    Then the school "Mystery Academy" should have no country

  # --------------------------------------------------------------------------
  # Grade level fix scenarios
  # --------------------------------------------------------------------------

  Scenario: Grade level is fixed when name and teachers agree (high confidence)
    # A school named "Springfield High School" is incorrectly set to elementary.
    # Two linked teachers both report education_level=high_school.
    # Both heuristics agree → high confidence → auto-fix.
    Given a school "Springfield High School" exists with grade level "elementary"
    And the school "Springfield High School" has 2 teachers with education level "high_school"
    When I run the rake task "schools:fix_grade_levels"
    Then the school "Springfield High School" should have grade level "high_school"

  Scenario: Grade level is not auto-fixed with low confidence (name only)
    # A school named "City Elementary" is set to high_school.
    # The name suggests elementary, but there are no teachers to confirm.
    # Low confidence → the task flags it but does not change the DB.
    Given a school "City Elementary" exists with grade level "high_school"
    When I run the rake task "schools:fix_grade_levels"
    Then the school "City Elementary" should have grade level "high_school"

  Scenario: A correctly-labeled school is not modified
    # Name says "High School" and grade_level is already high_school.
    # Nothing to fix.
    Given a school "Oak High School" exists with grade level "high_school"
    When I run the rake task "schools:fix_grade_levels"
    Then the school "Oak High School" should have grade level "high_school"
