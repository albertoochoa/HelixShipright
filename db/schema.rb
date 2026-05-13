# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_12_215553) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.string "from_state"
    t.jsonb "metadata", default: {}, null: false
    t.string "to_state"
    t.bigint "user_id"
    t.index ["auditable_type", "auditable_id", "created_at"], name: "idx_audit_logs_on_auditable_and_time"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "line_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.integer "unit_price_cents", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_line_items_on_order_id"
    t.index ["product_id"], name: "index_line_items_on_product_id"
    t.check_constraint "quantity > 0", name: "line_items_quantity_positive"
    t.check_constraint "unit_price_cents >= 0", name: "line_items_price_non_negative"
  end

  create_table "orders", force: :cascade do |t|
    t.string "carrier"
    t.datetime "created_at", null: false
    t.string "customer_email", null: false
    t.string "customer_name", null: false
    t.string "number", null: false
    t.datetime "placed_at", null: false
    t.text "shipping_address", null: false
    t.string "state", default: "pending", null: false
    t.string "tracking_number"
    t.datetime "tracking_synced_at"
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_orders_on_number", unique: true
    t.index ["placed_at"], name: "index_orders_on_placed_at"
    t.index ["state"], name: "index_orders_on_state"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "price_cents", default: 0, null: false
    t.string "sku", null: false
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tracking_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "external_id"
    t.string "location"
    t.datetime "occurred_at", null: false
    t.bigint "order_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "external_id"], name: "index_tracking_events_on_order_id_and_external_id", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["order_id", "occurred_at"], name: "index_tracking_events_on_order_id_and_occurred_at"
    t.index ["order_id"], name: "index_tracking_events_on_order_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "audit_logs", "users"
  add_foreign_key "line_items", "orders"
  add_foreign_key "line_items", "products"
  add_foreign_key "sessions", "users"
  add_foreign_key "tracking_events", "orders"
end
