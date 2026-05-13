FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "staff#{n}@example.com" }
    name { "Test Staff" }
    password { "password1234" }
  end
end
