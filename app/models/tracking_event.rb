class TrackingEvent < ApplicationRecord
  belongs_to :order

  validates :occurred_at, presence: true
  validates :status, presence: true

  scope :chronological, -> { order(occurred_at: :asc) }
end
