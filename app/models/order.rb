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
  validates :state, inclusion: { in: STATES.map (&:to_s) }

  scope :by_state, ->(state) { where(state: state) if state.present? }
  scope :most_recent, -> { order(created_at: :desc) }

  after_commit :sync_tracking_events_on_ship, on: :update

  aasm column: "state", whiny_persistence: true do
    # Wires every AASM transition into the audit trail. The block fires inside
    # the AASM lifecycle so from/to_state reflect the move being commited.
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
      # Orders that have already been delivered cannot be cancelled - meets
      # the business rules called out in the assignment
      transitions from: [:pending, :approved, :shipped], to: :cancelled
    end
  end

  def tracking_number_present?
    tracking_number.present? && carrier.present?
  end

  private

  # Fires only once the state change is durably commited - avoids the classic
  #  'jab ran before the transaction commited and saw stale data' race.

  def audit_state_change
    # aasm.current_event returns :approve! / ship! (the bag variant when
    # invoked via approve!) - strip the bang so the action stays canonical.
    event_name = aasm.current_event.to_s.chomp("!")
    record_audit!(
      action: "state_change:#{event_name}",
      from_state: aasm.from_state.to_s,
      to_state: aasm.to_state.to_s
    )
  end
end
