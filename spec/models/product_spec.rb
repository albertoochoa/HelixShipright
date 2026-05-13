require "rails_helper"

RSpec.describe Product, type: :model do
  it "is valid with a name, sku, and non-negative price" do
    expect(build(:product)).to be_valid
  end

  it "rejects duplicate SKUs" do
    create(:product, sku: "DUPE-1")
    expect(build(:product, sku: "DUPE-1")).not_to be_valid
  end

  it "rejects negative prices" do
    expect(build(:product, price_cents: -1)).not_to be_valid
  end
end
