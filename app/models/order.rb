class Order < ApplicationRecord
  include AASM
  include Auditable

  STATES = %i[pending approved shipped delivered cancelled].freeze

  has_many :line_items, dependent: :destroy, inverse_of: :order
  has_many :products, through: :line_items
  has_many :tracking_events, dependent: :destroy

  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :all_blank

  validates :number, presence: true, uniqueness: true
  validates :customer_name, :customer_email, :shipping_address, presence: true
  validates :customer_email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :placed_at, presence: true
  validates :state, inclusion: { in: STATES.map(&:to_s) }

  scope :by_state, ->(state) { where(state: state) if state.present? }
  scope :most_recent, -> { order(placed_at: :desc) }

  after_commit :sync_tracking_on_ship, on: :update

  aasm column: "state", whiny_persistence: true do
    after_all_transitions :audit_state_change

    state :pending, initial: true
    state :approved, :shipped, :delivered, :cancelled

    event :approve do
      transitions from: :pending, to: :approved
    end

    event :ship do
      transitions from: :approved, to: :shipped, guard: :tracking_number_present?
    end

    event :deliver do
      transitions from: :shipped, to: :delivered
    end

    event :cancel do
      transitions from: [:pending, :approved, :shipped], to: :cancelled
    end
  end

  def total_cents
    line_items.sum { |li| li.subtotal_cents }
  end

  def tracking_number_present?
    tracking_number.present? && carrier.present?
  end

  private

  def sync_tracking_on_ship
    return unless saved_change_to_state? && state == "shipped"
    SyncTrackingJob.perform_later(id)
  end

  def audit_state_change
    event_name = aasm.current_event.to_s.chomp("!")
    record_audit!(
      action: "state_change:#{event_name}",
      from_state: aasm.from_state.to_s,
      to_state: aasm.to_state.to_s
    )
  end
end