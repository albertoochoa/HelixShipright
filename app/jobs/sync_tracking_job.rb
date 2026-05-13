class SyncTrackingJob < ApplicationJob
  queue_as :default

  retry_on Carriers::TimeoutError, wait: :polynomially_longer, attempts: 5
  retry_on Carriers::ServerError, wait: :polynomially_longer, attempts: 5
  discard_on Carriers::InvalidPayload
  discard_on Carriers::NotFoundError

  def perform(order_id)
    order = Order.find_by(id: order_id)
    return unless order&.tracking_number_present?

    events = Carriers::Client.fetch_events(
      tracking_number: order.tracking_number,
      carrier: order.carrier
    )

    Order.transaction do
      events.each { |event| upsert_event(order, event) }
      order.update!(tracking_synced_at: Time.current)
    end

    broadcast_updates(order)
  end

  private

  def upsert_event(order, data)
    record = order.tracking_events.find_or_initialize_by(external_id: data.external_id)
    record.assign_attributes(
      occurred_at: data.occurred_at,
      status: data.status,
      location: data.location,
      description: data.description
    )
    record.save!
  end

  def broadcast_updates(order)
    Turbo::StreamsChannel.broadcast_replace_to(
      order,
      target: ActionView::RecordIdentifier.dom_id(order, :tracking),
      partial: "orders/tracking_timeline",
      locals: { order: order }
    )
  end
end