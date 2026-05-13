FactoryBot.define do
  factory :order do
    sequence(:number) { |n| "ORD-#{n.to_s.rjust(6, '0')}" }
    customer_name { "Jane Customer" }
    customer_email { "jane@example.com" }
    shipping_address { "123 Test Lane\nCincinnati, OH 45202" }
    placed_at { 1.day.ago }
    state { "pending" }

    trait :approved do
      state { "approved" }
    end

    trait :shipped do
      state { "shipped" }
      carrier { "ups" }
      tracking_number { "1Z999AA10123456784" }
    end

    trait :delivered do
      state { "delivered" }
      carrier { "ups" }
      tracking_number { "1Z999AA10123456784" }
    end

    trait :cancelled do
      state { "cancelled" }
    end

    trait :with_items do
      after(:build) do |order|
        product = create(:product)
        order.line_items.build(product: product, quantity: 2, unit_price_cents: product.price_cents)
      end
    end
  end
end
