# frozen_string_literal: true

Given(/the following email deliverability states exist/) do |emails_table|
  emails_table.symbolic_hashes.each do |row|
    email = EmailAddress.find_by!(email: row[:email])
    email.update!(
      emails_sent: row[:emails_sent].presence || email.emails_sent,
      emails_delivered: row[:emails_delivered].presence || email.emails_delivered,
      bounced: row[:bounced] == "true",
      suppressed_at: row[:suppressed_at].present? ? Time.zone.parse(row[:suppressed_at]) : nil,
      suppression_reason: row[:suppression_reason],
      last_delivery_event_type: row[:last_delivery_event_type],
      last_delivery_event_at: row[:last_delivery_event_at].present? ? Time.zone.parse(row[:last_delivery_event_at]) : nil
    )
  end
end