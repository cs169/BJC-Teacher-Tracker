# frozen_string_literal: true

class CreateSesDeliveryEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :ses_delivery_events do |t|
      t.references :email_address, foreign_key: true, null: true
      t.string :sns_message_id, null: false
      t.string :event_type, null: false
      t.string :bounce_type
      t.string :recipient_email, null: false
      t.datetime :event_occurred_at, null: false
      t.jsonb :payload, default: {}, null: false
      t.timestamps

      t.index [:sns_message_id, :recipient_email], unique: true, name: "idx_ses_events_dedupe"
      t.index :event_type
      t.index :recipient_email
    end
  end
end
