module Carriers
  module Client
    def fetch_events(tracking_number:, carrier:)
      adapter_for(carrier).fetch_events(tracking_number: tracking_number, carrier: carrier)
    end

    def adapter_for(_carrier)
      FakeClient.new
    end
  end
end
