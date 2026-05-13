class AuditLog < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :user, optional: true

  validates :action, presence: true

  scope :chronological, -> { order(created_at: :asc) }
  scope :recent_first, -> { order(created_at: :desc) }
end
