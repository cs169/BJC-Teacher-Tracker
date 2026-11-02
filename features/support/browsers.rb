# frozen_string_literal: true

# Selenium Driver Code:
# https://github.com/SeleniumHQ/selenium/tree/trunk/rb/lib/selenium/webdriver

# Original Source
# https://gist.github.com/bbonamin/4b01be9ed5dd1bdaf909462ff4fdca95
require "capybara/rspec"
require "selenium/webdriver"
require "cucumber"
require "active_support/all"

#### TODO: See if we can further simplify capybara setup.
# https://github.com/teamcapybara/capybara#drivers

# This returns a symbol representing the requested driver.
# By default this app selects a real browser for it's driver.
# We could speed up tests by using `rack_test`, but this doesn't work
# for JavaScript content and would require tagging scenarios with @javascript
def select_capybara_driver
  default_driver = :headless_chrome
  known_drivers = Capybara.drivers.names
  if ENV["DRIVER"].present?
    # be nice and accept 'Headless Chrome', spaces, etc.
    driver = ENV["DRIVER"].downcase.parameterize.underscore.to_sym
    if !known_drivers.include?(driver)
      puts "Unknown driver: \"#{driver}\".\nKnown drivers are: #{known_drivers.to_sentence}.\n"
      exit(1)
    end
    driver
  elsif ENV["GUI"].present?
    driver = :chrome
  else
    driver = default_driver
  end
  driver
end

### Google Chrome
# :selenium and :selenium_chrome do exist, but we want to customize some behavior.
# This allows us to control some behavior like downloading files and setting the screen size.
chrome_options = Selenium::WebDriver::Chrome::Options.new
chrome_options.add_preference(:download, prompt_for_download: false,
                                  default_directory: "/tmp/downloads")

chrome_options.add_preference(:browser, set_download_behavior: { behavior: "allow" })

Capybara.register_driver :chrome do |app|
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_options)
end

Capybara.register_driver :headless_chrome do |app|
  chrome_options.add_argument("--headless=new")
  chrome_options.add_argument("--disable-gpu")
  chrome_options.add_argument("--no-sandbox")
  chrome_options.add_argument("--disable-dev-shm-usage")
  chrome_options.add_argument("--window-size=1440,900")

  driver = Capybara::Selenium::Driver.new(app, browser: :chrome, options: chrome_options)

  ### Allow file downloads in Google Chrome when headless!
  ### https://bugs.chromium.org/p/chromium/issues/detail?id=696481#c89
  bridge = driver.browser.send(:bridge)
  path = "/session/#{bridge.session_id}/chromium/send_command"
  bridge.http.call(:post, path, cmd: "Page.setDownloadBehavior",
                                params: {
                                  behavior: "allow",
                                  downloadPath: "/tmp/downloads"
                                })
  driver
end

#### Safari (macOS only.)
# To enable safaridriver:
# https://developer.apple.com/documentation/webkit/testing_with_webdriver_in_safari/
# Get the Tech Preview:
# # https://developer.apple.com/safari/resources/
Capybara.register_driver :safari do |app|
  Capybara::Selenium::Driver.new(app, browser: :safari)
end

Capybara.register_driver :stp do |app|
  Selenium::WebDriver::Safari.technology_preview!
  Capybara::Selenium::Driver.new(app, browser: :safari)
end

### Firefox
Capybara.register_driver :firefox do |app|
  # This is really an alias for :selenium
  Capybara::Selenium::Driver.new(app, browser: :firefox)
end

Capybara.register_driver :headless_firefox do |app|
  # This is really an alias for :selenium_headless
  options = Selenium::WebDriver::Firefox::Options.new
  options.headless!
  Capybara::Selenium::Driver.new(app, browser: :firefox, options:)
end

Capybara.default_driver = select_capybara_driver
# Headless Chrome on CI is consistently slower than the 2s default. Bumping
# this to 10s prevents Selenium-driven assertions and finders from racing
# JavaScript that initializes asynchronously (DataTables, TinyMCE, Selectize,
# Bootstrap modals, OmniAuth-mocked redirects).
Capybara.default_max_wait_time = 10
puts "\nRUNNING CAPYBARA WITH DRIVER #{Capybara.default_driver}\n\n"
