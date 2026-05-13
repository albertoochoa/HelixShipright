require "rails_helper"

RSpec.describe Order, type: :model do
  describe "validations" do
    it "is valid with the factory" do
      expect(build(:order)).to be_valid
    end

    it "requires customer_email to look like an email" do
      order = build(:order, customer_email: "not-an-email")
      expect(order).not_to be_valid
      expect(order.errors[:customer_email]).to be_present
    end

    it "starts in the pending state" do
      expect(create(:order).state).to eq("pending")
    end
  end

  describe "state machine" do
    let(:order) { create(:order, :with_items) }

    it "advances pending → approved → shipped → delivered when tracking is set" do
      order.approve!
      expect(order).to be_approved

      order.update!(carrier: "ups", tracking_number: "1Z123")
      order.ship!
      expect(order).to be_shipped

      order.deliver!
      expect(order).to be_delivered
    end

    it "refuses to ship without a tracking number" do
      order.approve!
      expect { order.ship! }.to raise_error(AASM::InvalidTransition)
      expect(order.reload).to be_approved
    end

    it "refuses to ship directly from pending" do
      expect { order.ship! }.to raise_error(AASM::InvalidTransition)
      expect(order.reload).to be_pending
    end

    it "refuses to cancel a delivered order" do
      order.approve!
      order.update!(carrier: "ups", tracking_number: "1Z999")
      order.ship!
      order.deliver!

      expect { order.cancel! }.to raise_error(AASM::InvalidTransition)
      expect(order.reload).to be_delivered
    end

    it "permits cancellation from pending, approved, and shipped" do
      [
        create(:order, :with_items),
        create(:order, :with_items).tap(&:approve!),
        create(:order, :with_items).tap { |o|
          o.approve!
          o.update!(carrier: "ups", tracking_number: "1Z1")
          o.ship!
        }
      ].each do |o|
        o.cancel!
        expect(o).to be_cancelled
      end
    end
  end

  describe "#total_cents" do
    it "sums line item subtotals" do
      order = create(:order)
      product = create(:product, price_cents: 500)
      order.line_items.create!(product: product, quantity: 3)
      order.line_items.create!(product: product, quantity: 1, unit_price_cents: 200)

      expect(order.total_cents).to eq(3 * 500 + 200)
    end
  end

  describe "tracking sync enqueue (after_commit)" do
    let(:order) do
      create(:order, :with_items).tap do |o|
        o.approve!
        o.update!(carrier: "ups", tracking_number: "1Z123")
      end
    end

    it "enqueues SyncTrackingJob when the order ships" do
      expect { order.ship! }
        .to have_enqueued_job(SyncTrackingJob).with(order.id)
    end

    it "does not enqueue on non-state updates" do
      order.ship! # consume the initial enqueue from the ship transition
      expect { order.update!(tracking_number: "1Z999") }
        .not_to have_enqueued_job(SyncTrackingJob)
    end

    it "does not enqueue on transitions that aren't ship" do
      pending_order = create(:order, :with_items)
      expect { pending_order.approve! }.not_to have_enqueued_job(SyncTrackingJob)
      expect { pending_order.cancel! }.not_to have_enqueued_job(SyncTrackingJob)
    end
  end
end
