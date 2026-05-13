# Seeds an evaluator-ready dashboard: one staff login and a spread of orders
# distributed across every state in the AASM lifecycle.
#
# Idempotent — running `bin/rails db:seed` twice keeps a stable dataset.

require "faker"

Faker::Config.random = Random.new(42)

# Run any jobs the seed enqueues (e.g. tracking sync after ship!) synchronously
# so an evaluator sees a fully populated dashboard immediately.
ActiveJob::Base.queue_adapter = :inline

puts "Seeding staff user..."
staff = User.find_or_initialize_by(email_address: "staff@shipright.test")
staff.update!(
  name: "Ops Staff",
  password: "password1234",
  password_confirmation: "password1234"
)

puts "Seeding products..."
PRODUCT_CATALOG = [
  ["Hydration Pack 2L", "HYD-2L", 4900],
  ["Trail Runner Shoes", "TRR-SHOE", 12900],
  ["Quick-Dry Towel", "QDT-001", 1800],
  ["LED Headlamp", "HDL-LED", 3200],
  ["Insulated Bottle", "BTL-INS", 2500],
  ["Merino Wool Socks", "SOCK-MR", 1600],
  ["Carabiner Set (4pk)", "CAR-4PK", 900],
  ["Camp Stove", "STV-CAMP", 7800]
]

products = PRODUCT_CATALOG.map do |name, sku, price_cents|
  Product.find_or_create_by!(sku: sku) do |p|
    p.name = name
    p.price_cents = price_cents
  end
end

puts "Wiping prior demo orders..."
# Tracking events / audit logs / line items cascade via dependent: :destroy.
Order.where("number LIKE 'DEMO-%'").destroy_all

puts "Seeding orders across every state..."

def make_order(state:, number:, products:, days_ago:)
  order = Order.create!(
    number: number,
    customer_name: Faker::Name.name,
    customer_email: Faker::Internet.email,
    shipping_address: Faker::Address.full_address,
    placed_at: days_ago.days.ago,
    state: "pending" # AASM starts here; we advance below
  )

  rand(1..3).times do
    product = products.sample
    order.line_items.create!(product: product, quantity: rand(1..4))
  end

  # Mark up to the requested state. AASM enforces ordering, so this also
  # exercises the state machine end-to-end at seed time.
  order.approve! if %w[approved shipped delivered cancelled].include?(state)
  if %w[shipped delivered].include?(state)
    order.update!(carrier: "ups", tracking_number: "1Z#{SecureRandom.hex(6).upcase}")
    order.ship!
  end
  order.deliver! if state == "delivered"
  order.cancel! if state == "cancelled" && order.may_cancel?

  order
end

[
  [:pending, 5],
  [:approved, 4],
  [:shipped, 4],
  [:delivered, 3],
  [:cancelled, 2]
].each do |state, count|
  count.times do |i|
    number = format("DEMO-%s-%03d", state.to_s.upcase[0..2], i + 1)
    make_order(state: state.to_s, number: number, products: products, days_ago: rand(1..30))
  end
end

puts "Done."
puts "----"
puts "Login: staff@shipright.test / password1234"
puts "Orders by state:"
Order.group(:state).count.each { |state, count| puts "  #{state.ljust(10)} #{count}" }