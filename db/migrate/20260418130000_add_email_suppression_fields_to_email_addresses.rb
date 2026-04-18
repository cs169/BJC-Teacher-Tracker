class AddEmailSuppressionFieldsToEmailAddresses < ActiveRecord::Migration[6.1]
  def change
    add_column :email_addresses, :suppressed_at, :datetime
    add_column :email_addresses, :suppression_reason, :string
    add_column :email_addresses, :suppression_source, :string
    add_column :email_addresses, :last_delivery_event_type, :string
    add_column :email_addresses, :last_delivery_event_at, :datetime

    add_index :email_addresses, :suppressed_at
    add_index :email_addresses, :last_delivery_event_at
  end
end