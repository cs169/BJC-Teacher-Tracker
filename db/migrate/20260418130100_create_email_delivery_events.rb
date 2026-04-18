class CreateEmailDeliveryEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :email_delivery_events do |t|
      t.references :email_address, foreign_key: true
      t.integer :teacher_id
      t.string :provider, null: false, default: "aws_ses"
      t.string :sns_message_id, null: false
      t.string :ses_message_id
      t.string :event_type, null: false
      t.string :recipient_email, null: false
      t.string :mailer_action
      t.string :bounce_type
      t.string :bounce_sub_type
      t.string :complaint_feedback_type
      t.datetime :event_occurred_at, null: false
      t.jsonb :message_tags, null: false, default: {}
      t.jsonb :payload, null: false, default: {}

      t.timestamps
    end

    add_foreign_key :email_delivery_events, :teachers, column: :teacher_id
    add_index :email_delivery_events, [:provider, :sns_message_id, :recipient_email], unique: true, name: "idx_email_delivery_events_dedupe"
    add_index :email_delivery_events, [:email_address_id, :event_occurred_at], name: "idx_email_delivery_events_by_email"
    add_index :email_delivery_events, [:teacher_id, :event_occurred_at], name: "idx_email_delivery_events_by_teacher"
    add_index :email_delivery_events, [:event_type, :event_occurred_at], name: "idx_email_delivery_events_by_type"
    add_index :email_delivery_events, :recipient_email
    add_index :email_delivery_events, :ses_message_id
  end
end