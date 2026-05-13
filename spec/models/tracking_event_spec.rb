require "rails_helper"

RSpec.describe TrackingEvent, type: :model do
  it "requires occurred_at and status" do
    event = TrackingEvent.new(order: create(:order))
    expect(event).not_to be_valid
    expect(event.errors[:occurred_at]).to be_present
    expect(event.errors[:status]).to be_present
  end

  it ".chronological orders oldest first" do
    order = create(:order, :shipped)
    later = create(:tracking_event, order: order, occurred_at: 1.hour.ago)
    early = create(:tracking_event, order: order, occurred_at: 5.hours.ago)

    expect(order.tracking_events.chronological).to eq([early, later])
  end
end
