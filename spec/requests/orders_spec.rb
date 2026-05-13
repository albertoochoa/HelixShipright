require "rails_helper"

RSpec.describe "Orders", type: :request do
  let(:user) { create(:user) }

  describe "authentication" do
    it "redirects unauthenticated requests to sign in" do
      get orders_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /orders" do
    before { sign_in_as(user) }

    it "lists orders" do
      create(:order, :with_items, customer_name: "Alice")
      get orders_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
    end

    it "filters by state" do
      pending = create(:order, customer_name: "Pending Person")
      create(:order, :approved, customer_name: "Approved Person")

      get orders_path(state: "pending")
      expect(response.body).to include("Pending Person")
      expect(response.body).not_to include("Approved Person")
    end
  end

  describe "POST /orders/:id/transition" do
    before { sign_in_as(user) }

    let!(:order) { create(:order, :with_items) }

    it "advances a valid transition" do
      post transition_order_path(order, event: "approve")
      expect(order.reload).to be_approved
      expect(response).to redirect_to(order)
      follow_redirect!
      expect(response.body).to include("approved")
    end

    it "returns a friendly flash on an invalid transition instead of 500" do
      # ship requires a tracking number; this order has none
      order.approve!
      post transition_order_path(order, event: "ship")
      expect(response).to redirect_to(order)
      follow_redirect!
      expect(response.body).to match(/Cannot ship/i)
      expect(order.reload).to be_approved
    end
  end

  describe "POST /orders/bulk_transition" do
    before { sign_in_as(user) }

    it "applies the event to every selected order and reports results" do
      pending = Array.new(2) { create(:order, :with_items) }
      shipped = create(:order, :with_items).tap(&:approve!)

      post bulk_transition_orders_path,
           params: { event: "approve", order_ids: pending.map(&:id) + [shipped.id] }

      expect(pending.map { |o| o.reload.state }).to all(eq("approved"))
      expect(shipped.reload).to be_approved # already approved — still ok
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "skips orders where the transition is invalid" do
      delivered = create(:order, :with_items).tap { |o|
        o.approve!
        o.update!(carrier: "ups", tracking_number: "1Z123")
        o.ship!
        o.deliver!
      }

      post bulk_transition_orders_path,
           params: { event: "cancel", order_ids: [delivered.id] }

      follow_redirect!
      expect(response.body).to include("Skipped")
      expect(delivered.reload).to be_delivered
    end
  end
end
