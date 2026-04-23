# frozen_string_literal: true

# MailBluster API configuration
# Set the MAILBLUSTER_API_KEY environment variable to enable integration.
# Get your API key from: https://app.mailbluster.com/api-doc/getting-started
#
# In development, you can set it in config/application.yml:
#   MAILBLUSTER_API_KEY: "your-api-key-here"

Rails.application.config.after_initialize do
  if ENV["MAILBLUSTER_API_KEY"].blank? && !Rails.env.test?
    Rails.logger.warn("[MailBluster] MAILBLUSTER_API_KEY is not set. MailBluster sync will be disabled.")
  end
end
