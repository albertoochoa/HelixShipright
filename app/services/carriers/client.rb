module Carriers
  class Client
    def self.fetch_events(tracking_number:, carrier:)
      adapter_for(carrier).fetch_events(tracking_number: tracking_number, carrier: carrier)
    end

    def self.adapter_for(_carrier)
      FakeClient.new
    end
  end
end
