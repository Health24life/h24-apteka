# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OrderPolicy do
  def open?(order, user_id: nil)
    described_class.new(Orders::Carts::Owner.new(user_id:, token: order.token), order).open?
  end

  it "opens a guest's order to whoever holds its token, signed in or not", :aggregate_failures do
    order = build(:order)

    expect(open?(order)).to be(true)
    expect(open?(order, user_id: 9)).to be(true)
  end

  it "opens an account's order only to the user of that account", :aggregate_failures do
    order = build(:order, user_id: 7)

    expect(open?(order, user_id: 7)).to be(true)
    expect(open?(order)).to be(false)
    expect(open?(order, user_id: 8)).to be(false)
  end
end
