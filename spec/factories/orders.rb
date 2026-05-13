FactoryBot.define do
  factory :order do
    number { "MyString" }
    state { "MyString" }
    customer_name { "MyString" }
    customer_email { "MyString" }
    shipping_address { "MyText" }
    carrier { "MyString" }
    tracking_number { "MyString" }
    tracking_synced_at { "2026-05-12 17:55:36" }
    placed_at { "2026-05-12 17:55:36" }
  end
end
