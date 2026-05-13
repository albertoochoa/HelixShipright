module Carriers
  class FakeClient
    DEFAULT_FAILURE_RATE = 0.0
    DEFAULT_LATENCY_MS = 0

    def initialize(failure_rate: DEFAULT_FAILURE_RATE, latency_ms: DEFAULT_LATENCY_MS, clock: Time)
      @failure_rate = failure_rate
      @latency_ms = latency_ms
      @clock = clock
    end

    def fetch_events(tracking_number:, carrier:)
      raise ArgumentError, "tracking_number required" if tracking_number.blank?

      simulate_latency
      maybe_fail!

      seed = Digest::MD5.hexdigest("#{carrier}-#{tracking_number}").to_i(16)
      rng = Random.new(seed)

      base_time = @clock.now - rng.rand(2..6).hours
      milestones(rng).each_with_index.map do |(status, location, description), idx|
        TrackingEventData.new(
          external_id: "#{tracking_number}-#{idx}",
          occurred_at: base_time + (idx * rng.rand(20..120)).minutes,
          status: status,
          location: location,
          description: description
        )
      end
    end

    private

    def simulate_latency
      return if @latency_ms.to_i <= 0
      sleep(@latency_ms / 1000.0)
    end

    def maybe_fail!
      return if @failure_rate.to_f <= 0
      roll = SecureRandom.random_number
      return if roll >= @failure_rate

      case (roll * 100).to_i % 3
      when 0 then raise TimeoutError, "carrier API timed out"
      when 1 then raise ServerError, "carrier API 5xx"
      else raise InvalidPayload, "carrier returned malformed payload"
      end
    end

    def milestones(rng)
      [
        ["label_created", "Origin Facility", "Shipping label created"],
        ["picked_up", "Origin Facility", "Picked up by carrier"],
        ["in_transit", city(rng), "Departed sorting facility"],
        ["out_for_delivery", city(rng), "Out for delivery"]
      ]
    end

    def city(rng)
      ["Cincinnati, OH", "Louisville, KY", "Memphis, TN", "Atlanta, GA", "Dallas, TX"].sample(random: rng)
    end
  end
end