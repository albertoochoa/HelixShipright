class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :auditable, polymorphic: true, null: false
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :from_state
      t.string :to_state
      t.jsonb :metadata, null: false, default: {}

      t.datetime :created_at, null: false
    end
    add_index :audit_logs, [:auditable_type, :auditable_id, :created_at], name: "idx_audit_logs_on_auditable_and_time"
  end
end
