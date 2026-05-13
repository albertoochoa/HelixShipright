class CreateLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :line_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :unit_price_cents, null: false

      t.timestamps
    end
    add_check_constraint :line_items, "quantity > 0", name: "line_items_quantity_positive"
    add_check_constraint :line_items, "unit_price_cents >= 0", name: "line_items_price_non_negative"
  end
end
