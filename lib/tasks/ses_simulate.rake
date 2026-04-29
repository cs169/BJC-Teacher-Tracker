# frozen_string_literal: true

# Dev-only helper: fires a fake SES event at SesEventProcessor so you can
# watch the Email Delivery Stats counters update on the teacher show page
# without needing real AWS traffic. Remove this file once the integration
# has been verified in a real environment.
namespace :ses do
  FIXTURE_DIR = Rails.root.join("spec/fixtures/files/ses")
  EVENT_FIXTURES = {
    "send" => "send",
    "delivery" => "delivery",
    "soft_bounce" => "soft_bounce",
    "hard_bounce" => "hard_bounce",
    "complaint" => "complaint"
  }.freeze

  desc "Fire a fake SES event at a teacher's email. Usage: rake 'ses:simulate[teacher@example.com,delivery]'"
  task :simulate, [:email, :event] => :environment do |_t, args|
    email = args[:email]
    event_key = (args[:event] || "delivery").downcase

    if email.blank?
      puts "Usage: rake 'ses:simulate[teacher@example.com,delivery]'"
      puts "  event can be: #{EVENT_FIXTURES.keys.join(', ')}"
      exit 1
    end

    fixture_name = EVENT_FIXTURES[event_key]
    if fixture_name.nil?
      puts "Unknown event #{event_key.inspect}. Valid: #{EVENT_FIXTURES.keys.join(', ')}"
      exit 1
    end

    payload = JSON.parse(File.read(FIXTURE_DIR.join("#{fixture_name}.json")))
    rewrite_recipient!(payload, email)

    sns_message_id = "dev-sim-#{SecureRandom.hex(6)}"
    SesEventProcessor.new(payload, sns_message_id:).call

    record = EmailAddress.find_by(email:)
    if record
      puts "Fired #{payload["eventType"]} for #{email} (sns_message_id=#{sns_message_id})"
      puts "  emails_sent=#{record.emails_sent}, emails_delivered=#{record.emails_delivered}, " \
           "soft_bounce_count=#{record.soft_bounce_count}, hard_bounce_count=#{record.hard_bounce_count}, " \
           "bounced=#{record.bounced}"
    else
      puts "Fired #{payload["eventType"]} for #{email} but no EmailAddress record exists — event stored with email_address_id=nil."
    end
  end

  desc "Reset all SES-derived counters and delete SesDeliveryEvent rows (dev only)"
  task reset: :environment do
    abort "Refusing to run in #{Rails.env}." unless Rails.env.development? || Rails.env.test?

    EmailAddress.update_all(
      emails_sent: 0,
      emails_delivered: 0,
      soft_bounce_count: 0,
      hard_bounce_count: 0,
      bounced: false,
      last_ses_event_at: nil
    )
    SesDeliveryEvent.delete_all
    puts "Reset SES counters on #{EmailAddress.count} email addresses and cleared SesDeliveryEvent rows."
  end

  def rewrite_recipient!(payload, email)
    payload["mail"] ||= {}
    payload["mail"]["destination"] = [email]
    payload["mail"]["commonHeaders"] ||= {}
    payload["mail"]["commonHeaders"]["to"] = [email]

    if payload["delivery"].is_a?(Hash)
      payload["delivery"]["recipients"] = [email]
    end

    if payload["bounce"].is_a?(Hash) && payload["bounce"]["bouncedRecipients"].is_a?(Array)
      payload["bounce"]["bouncedRecipients"] = [{ "emailAddress" => email }]
    end

    if payload["complaint"].is_a?(Hash) && payload["complaint"]["complainedRecipients"].is_a?(Array)
      payload["complaint"]["complainedRecipients"] = [{ "emailAddress" => email }]
    end
  end
end
