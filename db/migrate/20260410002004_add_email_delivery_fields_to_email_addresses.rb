class AddEmailDeliveryFieldsToEmailAddresses < ActiveRecord::Migration[6.1]
  def change
    add_column :email_addresses, :emails_sent, :integer, default: 0, null: false
    add_column :email_addresses, :emails_delivered, :integer, default: 0, null: false
    add_column :email_addresses, :bounced, :boolean, default: false, null: false
  end
end
