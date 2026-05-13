require "rails_helper"

RSpec.describe LineItem, type: :model do
  it "copies unit price from the product when none is given" do
    order = create(:order)
    product = create(:product, price_cents: 750)
    item = order.line_items.create!(product: product, quantity: 2)

    expect(item.unit_price_cents).to eq(750)
  end

  it "respects an explicit unit_price_cents override" do
    order = create(:order)
    product = create(:product, price_cents: 750)
    item = order.line_items.create!(product: product, quantity: 2, unit_price_cents: 1)

    expect(item.unit_price_cents).to eq(1)
  end

  it "computes subtotal_cents" do
    item = build(:line_item, quantity: 3, unit_price_cents: 250)
    expect(item.subtotal_cents).to eq(750)
  end

  it "rejects non-positive quantities" do
    expect(build(:line_item, quantity: 0)).not_to be_valid
    expect(build(:line_item, quantity: -1)).not_to be_valid
  end
end
