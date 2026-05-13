class OrdersController < ApplicationController
  before_action :set_order, only: [:show, :transition, :sync_tracking]

  def index
    @state_filter = params[:state].presence
    @orders = Order.includes(:line_items)
                   .by_state(@state_filter)
                   .most_recent
    @state_counts = Order.group(:state).count
  end

  def show
    @audit_logs = @order.audit_logs.recent_first.includes(:user)
    @tracking_events = @order.tracking_events.chronological
  end

  def transition
    event = params.require(:event).to_sym
    success = apply_transition!(@order, event)

    respond_to do |format|
      format.turbo_stream do
        flash.now[success ? :notice : :alert] = @flash_message
        render turbo_stream: order_transition_streams(@order)
      end
      format.html do
        flash[success ? :notice : :alert] = @flash_message
        redirect_to @order
      end
    end
  rescue ActionController::ParameterMissing
    redirect_to @order, alert: "No transition specified."
  end

  def sync_tracking
    SyncTrackingJob.perform_later(@order.id)
    redirect_to @order, notice: "Tracking refresh queued."
  end

  def bulk_transition
    event = params.require(:event).to_sym
    ids = Array(params[:order_ids]).reject(&:blank?).map(&:to_i)

    if ids.empty?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Select at least one order."
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        end
        format.html { redirect_to orders_path, alert: "Select at least one order." }
      end
      return
    end

    succeeded = []
    skipped = []
    touched = []

    Order.where(id: ids).find_each do |order|
      if apply_transition!(order, event)
        succeeded << order.number
        touched << order
      else
        skipped << "#{order.number} (#{@flash_message})"
      end
    end

    notice = "#{succeeded.length} order(s) transitioned."
    notice << " Skipped: #{skipped.join('; ')}" if skipped.any?

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = notice
        streams = touched.map { |o| turbo_stream.replace(o) }
        streams << turbo_stream.replace("flash", partial: "shared/flash")
        render turbo_stream: streams
      end
      format.html { redirect_to orders_path(state: params[:state]), notice: notice }
    end
  rescue ActionController::ParameterMissing
    redirect_to orders_path, alert: "No transition specified."
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def apply_transition!(order, event)
    unless order.aasm.events(permitted: true).map(&:name).include?(event)
      @flash_message = "Cannot #{event} an order in '#{order.state}' state."
      return false
    end

    order.send("#{event}!")
    @flash_message = "Order #{order.number} marked as #{order.state}."
    true
  rescue AASM::InvalidTransition => e
    @flash_message = e.message
    false
  rescue ActiveRecord::RecordInvalid => e
    @flash_message = e.message
    false
  end

  def order_transition_streams(order)
    [
      turbo_stream.replace(dom_id(order, :badge), partial: "orders/state_badge", locals: { order: order }),
      turbo_stream.replace(dom_id(order, :actions), partial: "orders/actions", locals: { order: order }),
      turbo_stream.replace("flash", partial: "shared/flash")
    ]
  end
end