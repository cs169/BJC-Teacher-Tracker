# frozen_string_literal: true

class AddBounceCountsToEmailAddresses < ActiveRecord::Migration[6.1]
  def change
    add_column :email_addresses, :soft_bounce_count, :integer, default: 0, null: false
    add_column :email_addresses, :hard_bounce_count, :integer, default: 0, null: false
    add_column :email_addresses, :last_ses_event_at, :datetime
  end
end
