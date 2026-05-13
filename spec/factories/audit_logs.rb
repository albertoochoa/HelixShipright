FactoryBot.define do
  factory :audit_log do
    auditable { nil }
    user { nil }
    action { "MyString" }
    from_state { "MyString" }
    to_state { "MyString" }
    metadata { "" }
  end
end
