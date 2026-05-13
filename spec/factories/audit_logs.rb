FactoryBot.define do
  factory :audit_log do
    association :auditable, factory: :order
    action { "state_change:approve" }
    from_state { "pending" }
    to_state { "approved" }
    metadata { {} }
  end
end
