require "rails_helper"

RSpec.describe Carriers::FakeClient do
  subject(:client) { described_class.new }

  describe "#fetch_events" do
    it "rejects a blank tracking number" do
      expect { client.fetch_events(tracking_number: "", carrier: "ups") }
        .to raise_error(ArgumentError)
    end

    it "returns deterministic events for the same tracking number" do
      events_a = client.fetch_events(tracking_number: "1ZABC", carrier: "ups")
      events_b = client.fetch_events(tracking_number: "1ZABC", carrier: "ups")
      expect(events_a.map(&:external_id)).to eq(events_b.map(&:external_id))
      expect(events_a.map(&:status)).to eq(events_b.map(&:status))
    end

    it "returns Carriers::TrackingEventData value objects" do
      events = client.fetch_events(tracking_number: "1ZXYZ", carrier: "ups")
      expect(events).to all(be_a(Carriers::TrackingEventData))
      expect(events.first.status).to be_a(String)
    end
  end

  describe "failure injection" do
    it "raises a Carriers::Error subclass when failure_rate is 1.0" do
      noisy = described_class.new(failure_rate: 1.0)
      expect { noisy.fetch_events(tracking_number: "1Z1", carrier: "ups") }
        .to raise_error(Carriers::Error)
    end
  end
end
