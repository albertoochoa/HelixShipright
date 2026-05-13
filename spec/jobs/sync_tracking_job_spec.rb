require "rails_helper"

RSpec.describe SyncTrackingJob, type: :job do
  let(:order) { create(:order, :shipped) }

  it "no-ops when the order doesn't exist" do
    expect { described_class.perform_now(0) }.not_to raise_error
  end

  it "no-ops when the order has no tracking number" do
    bare = create(:order)
    expect { described_class.perform_now(bare.id) }.not_to change(TrackingEvent, :count)
  end

  it "persists events returned by the carrier and updates tracking_synced_at" do
    fake_events = [
      Carriers::TrackingEventData.new(
        external_id: "ext-1", occurred_at: 1.hour.ago, status: "picked_up",
        location: "Origin", description: "Picked up"
      )
    ]
    allow(Carriers::Client).to receive(:fetch_events).and_return(fake_events)

    expect { described_class.perform_now(order.id) }.to change(TrackingEvent, :count).by(1)
    expect(order.reload.tracking_synced_at).to be_present
  end

  it "is idempotent: re-running upserts on external_id rather than duplicating" do
    fake_events = [
      Carriers::TrackingEventData.new(
        external_id: "ext-1", occurred_at: 1.hour.ago, status: "picked_up",
        location: "Origin", description: "Picked up"
      )
    ]
    allow(Carriers::Client).to receive(:fetch_events).and_return(fake_events)

    described_class.perform_now(order.id)
    expect { described_class.perform_now(order.id) }.not_to change(TrackingEvent, :count)
  end

  it "discards InvalidPayload without retrying" do
    allow(Carriers::Client).to receive(:fetch_events).and_raise(Carriers::InvalidPayload, "bad")
    # discard_on swallows the error; should not propagate or raise
    expect { described_class.perform_now(order.id) }.not_to raise_error
  end
end
