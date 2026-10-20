# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Bookings::Cancel do
  let(:order) do
    create(:order, :submitted, provider: create(:provider, code: 'pharmapoint'), user_id: 7, status_name: 'created')
  end

  def owner(user_id: 7) = Orders::Carts::Owner.new(user_id:, token: order.token)

  it 'cancels at the provider and reads the status again', :aggregate_failures do
    adapter = stub_bookings_adapter(submit: partner_order(status_name: 'canceled'))

    expect(described_class.call(owner, reason: 'Передумала').status_name).to eq('canceled')
    expect(adapter.cancelled).to eq([ 'Передумала' ])
  end

  it 'sends a reason of its own when the user gives none' do
    adapter = stub_bookings_adapter

    described_class.call(owner)

    expect(adapter.cancelled).to eq([ 'Скасовано клієнтом' ])
  end

  it 'lets only the user of the account cancel, not whoever holds the link or a guest', :aggregate_failures do
    stub_bookings_adapter

    expect do
 described_class.call(owner(user_id: nil))
    end.to be_refused(code: :cancellation_needs_account, status: :forbidden)
    expect { described_class.call(owner(user_id: 8)) }.to be_refused(code: :cancellation_needs_account)
  end

  it 'refuses an order with a final status or one the provider never took', :aggregate_failures do
    stub_bookings_adapter
    order.update!(status_name: 'canceled')
    expect { described_class.call(owner) }.to be_refused(code: :order_not_cancellable, status: :conflict)

    failed = create(:order, :submission_failed, user_id: 7)
    expect { described_class.call(Orders::Carts::Owner.new(user_id: 7, token: failed.token)) }
      .to be_refused(code: :order_not_cancellable)
  end

  it 'refuses a reason longer than allowed' do
    stub_bookings_adapter

    expect { described_class.call(owner, reason: 'x' * 256) }.to be_refused(code: :invalid_cancel_reason)
  end

  it 'tells a refusal of the partner from it not answering', :aggregate_failures do
    stub_bookings_adapter(cancel: Orders::Bookings::Failure.new(reason: :refused, retry_after: nil))
    expect { described_class.call(owner) }.to be_refused(code: :cancellation_refused, status: :conflict)

    stub_bookings_adapter(cancel: Orders::Bookings::Failure.new(reason: :unavailable, retry_after: nil))
    expect { described_class.call(owner) }.to be_refused(code: :cancellation_unavailable, status: :service_unavailable)
  end
end
