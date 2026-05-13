require "rails_helper"

RSpec.describe AuditLog, type: :model do
  it "is created automatically on every order state transition" do
    user = create(:user)
    Current.session = user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")
    order = create(:order, :with_items)

    expect { order.approve! }.to change { order.audit_logs.count }.by(1)

    log = order.audit_logs.last
    expect(log.action).to eq("state_change:approve")
    expect(log.from_state).to eq("pending")
    expect(log.to_state).to eq("approved")
    expect(log.user).to eq(user)
  ensure
    Current.session = nil
  end

  it "records system actions when no Current.user is set" do
    order = create(:order, :with_items)
    expect { order.approve! }.to change { order.audit_logs.count }.by(1)
    expect(order.audit_logs.last.user).to be_nil
  end
end
