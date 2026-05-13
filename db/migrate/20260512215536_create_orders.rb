class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :number, null: false
      t.string :state, null: false, default: "pending"
      t.string :customer_name, null: false
      t.string :customer_email, null: false
      t.text :shipping_address, null: false
      t.string :carrier
      t.string :tracking_number
      t.datetime :tracking_synced_at
      t.datetime :placed_at, null: false

      t.timestamps
    end
    add_index :orders, :number, unique: true
    add_index :orders, :state
    add_index :orders, :placed_at
  end
end
