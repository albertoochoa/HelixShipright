class CreateTrackingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :tracking_events do |t|
      t.references :order, null: false, foreign_key: true
      t.datetime :occurred_at, null: false
      t.string :status, null: false
      t.string :location
      t.text :description
      t.string :external_id

      t.timestamps
    end
    add_index :tracking_events, [:order_id, :external_id], unique: true, where: "external_id IS NOT NULL"
    add_index :tracking_events, [:order_id, :occurred_at]
  end
end
