FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    sequence(:sku) { |n| "SKU-#{n.to_s.rjust(4, '0')}" }
    price_cents { 1999 }
  end
end
