module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, as: :auditable, dependent: :destroy
  end

  def record_audit!(action:, user: Current.user, from_state: nil, to_state: nil, metadata: {})
    audit_logs.create!(
      user: user,
      action: action.to_s,
      from_state: from_state,
      to_state: to_state,
      metadata: metadata
    )
  end
end
