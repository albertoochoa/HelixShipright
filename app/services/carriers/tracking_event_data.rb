module Carriers
  TrackingEventData = Data.define(:external_id, :occurred_at, :status, :location, :description)
end
