FactoryBot.define do
  factory :tracking_event do
    order { nil }
    occurred_at { "2026-05-12 17:55:48" }
    status { "MyString" }
    location { "MyString" }
    description { "MyText" }
  end
end
