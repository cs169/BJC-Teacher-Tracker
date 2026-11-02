Feature: pages features as an admin

    As an admin, I should be able to create, view, and edit pages

Background: I am logged in as an admin
    Given the following teachers exist:
    | first_name | last_name | admin | primary_email                |
    | Joseph     | Mamoa     | true  | testadminuser@berkeley.edu   |
    Given I am on the BJC home page
    Given I have an admin email
    And I follow "Log In"
    Then I can log in with Google
    And I should see "BJC Teacher Dashboard"

Scenario: Pressing "pages" button on navbar should take me to a list of all pages
    Given I follow "Pages"
    Then I should be on the pages index
    And I should see "Title"
    And I should see "Permissions"
    And I should not see "Content"

Scenario: Pressing "New Page" button should take user to new page form
    Given I am on the pages index
    And I press "New Page"
    Then I should be on the new pages page
    And I should see "Title"
    And I should see "Permissions"
    And I should see "URL slug"
    And I should see "Content"
    And I should see "Category"

Scenario: Successfully creating a new page redirects to that page
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I fill in "page_category" with "Test Category"
    And I fill in the page HTML content with "This is a test"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    Then I should see "Test Title"
    Then I should see "This is a test"
    And I should see a nav link "Test Category"
    And I should have a hidden page link "Test Title"

Scenario: Creating a page without a title fails
    Given I am on the new pages page
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I fill in "page_category" with "Test Category"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    Then The "#new_page" form is invalid
    And I should be on the new pages page

Scenario: Creating a page without a slug fails
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_category" with "Test Category"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    Then The "#new_page" form is invalid
    And I should be on the new pages page

Scenario: Creating a page without choosing permissions fails
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I fill in "page_category" with "Test Category"
    And I fill in the page HTML content with "This is a test"
    And I press "Submit"
    Then The "#new_page" form is invalid
    And I should be on the new pages page

Scenario: I create a new page and I can see it on the index page
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I fill in "page_category" with "Test Category"
    And I fill in the page HTML content with "This is a test"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    And I follow "Pages"
    Then I should see "Test Title"
    And I should see "Admin"
    And I should see a nav link "Test Category"
    And I should have a hidden page link "Test Title"

Scenario: Can create a new page with the same title as a page that already exists
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I fill in the page HTML content with "This is a test"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    And I follow "Pages"
    And I press "New Page"
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug_2"
    And I choose "inlineRadioAdmin"
    And I fill in the page HTML content with "This is a test"
    And I press "Submit"
    Then I should see "Test Title"

Scenario: Can't create a page with a slug that already exists
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I fill in the page HTML content with "This is a test"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    And I follow "Pages"
    And I press "New Page"
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    Then I should see "Create Test Title"
    And I should see "URL slug has already been taken"

Scenario: Can't create a default admin page
   Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I fill in "page_category" with "Test Category"
    And I check "page_default" checkbox
    And I fill in the page HTML content with "This is a test"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    Then I should see "Create Test Title"
    And I should see "error"

Scenario: Attempting to create page with taken slug doesn't delete form input
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I fill in the page HTML content with "Don't see this"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    And I follow "Pages"
    And I press "New Page"
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I fill in the page HTML content with "This is a test"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    Then I should see "Create Test Title"
    And I should see "URL slug has already been taken"
    And the "page_title" field should contain "Test Title"
    And the "page_url_slug" field should contain "basic_slug"
    And I should see the page HTML content containing "This is a test"
    And I should not see "Don't see this"

Scenario: I can delete pages
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "basic_slug"
    And I fill in the page HTML content with "This is a test"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    And I follow "Pages"
    When I press the delete button for "basic_slug"
    Then I should not see "basic_slug"

Scenario: Can create pages with any selection for permissions
    Given I am on the new pages page
    And I fill in "page_title" with "Admin Permissions"
    And I fill in "page_url_slug" with "basic_slug"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    And I follow "Pages"
    And I press "New Page"
    And I fill in "page_title" with "Verified Teacher Permissions"
    And I fill in "page_url_slug" with "basic_slug_2"
    And I choose "inlineRadioTeacher"
    And I press "Submit"
    And I follow "Pages"
    And I press "New Page"
    And I fill in "page_title" with "Public Permissions"
    And I fill in "page_url_slug" with "basic_slug_3"
    And I choose "inlineRadioPublic"
    And I press "Submit"

Scenario: Correctly store user's full name and create date.
    Given I am on the pages index
    And I press "New Page"
    Then I should be on the new pages page
    And I fill in "page_title" with "Test page"
    And I fill in "page_url_slug" with "Test"
    And I fill in the page HTML content with "Test Content"
    And I choose "inlineRadioAdmin"
    And I press "Submit"
    Then I follow "Pages"
    And I should see "Joseph Mamoa"

Scenario: Can edit pages with correct prefilled content in the form.
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I choose "inlineRadioAdmin"
    And I fill in the page HTML content with "This is a test"
    And I press "Submit"
    And I follow "Pages"
    And I press the edit button for "cucumber_test_page"
    Then I should be on the edit pages page for "cucumber_test_page"
    And the "page_title" field should contain "Test Title"
    And the "page_url_slug" field should contain "cucumber_test_page"
    And I should see the page HTML content containing "This is a test"
    Then I fill in "page_title" with "New Title"
    And I fill in "page_url_slug" with "new_slug"
    And I choose "inlineRadioPublic"
    And I fill in the page HTML content with "This is a test 2"
    And I press "Update"
    Then I should see "New Title"
    And I should see "Public"
    Then I should be on the pages index
    And I should not see "Test Title"
    And I should not see "cucumber_test_page"

Scenario: Can update page even if no changes
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I choose "inlineRadioAdmin"
    And I fill in the page HTML content with "This is a test"
    And I press "Submit"
    And I follow "Pages"
    And I press the edit button for "cucumber_test_page"
    Then I should be on the edit pages page for "cucumber_test_page"
    And I press "Update"
    Then I should be on the pages index
    And I should see "Test Title"
    And I should see "Admin"

Scenario: Attempting to update page with taken slug doesn't delete form input
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title"
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I choose "inlineRadioAdmin"
    And I fill in the page HTML content with "This is a test"
    And I press "Submit"
    And I wait for TinyMCE to load
    Given I am on the new pages page
    And I fill in "page_title" with "Test Title 2"
    And I fill in "page_url_slug" with "basic_slug_2"
    And I choose "inlineRadioAdmin"
    And I fill in the page HTML content with "This is a test"
    And I press "Submit"
    Then I follow "Pages"
    And I press the edit button for "basic_slug_2"
    Then I should be on the edit pages page for "basic_slug_2"
    And I fill in "page_title" with "New Title"
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I fill in the page HTML content with "New page body."
    And I press "Update"
    Then I should see "Update New Title"
    And I should see "URL slug has already been taken"
    And the "page_title" field should contain "New Title"
    And the "page_url_slug" field should contain "cucumber_test_page"
    And I should see the page HTML content containing "New page body."

Scenario: Clicking radio button text selects that radio button
    Given I am on the new pages page
    And I choose "Admin"
    Then The radio button "inlineRadioAdmin" should be checked
    And I choose "Verified Teacher"
    Then The radio button "inlineRadioTeacher" should be checked
    And I choose "Public"
    Then The radio button "inlineRadioPublic" should be checked

Scenario: Cannot update admin page to be default
    Given I am on the new pages page
    And I fill in "page_title" with "Test Default Title"
    And I fill in "page_url_slug" with "cucumber_test_page"
    And I choose "inlineRadioAdmin"
    And I fill in the page HTML content with "This is a test"
    And I press "Submit"
    And I follow "Pages"
    And I press the edit button for "cucumber_test_page"
    Then I should be on the edit pages page for "cucumber_test_page"
    And I check "page_default" checkbox
    And I press "Update"
    Then I should see "Update Test Default Title"
    And I should see "error"
