FactoryBot.define do
  factory :tracking_event do
    order
    occurred_at { Time.current }
    status { "in_transit" }
    location { "Cincinnati, OH" }
    description { "Departed sorting facility" }
  end
end
