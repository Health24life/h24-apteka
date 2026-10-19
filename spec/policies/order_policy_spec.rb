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

  def policy(order, user_id: nil) = described_class.new(Orders::Carts::Owner.new(user_id:, token: order.token), order)

  it "shows a sent order to whoever holds its link, an account's cart only to its user", :aggregate_failures do
    expect(policy(build(:order, :submitted, user_id: 7)).show?).to be(true)
    expect(policy(build(:order, user_id: 7)).show?).to be(false)
  end

  it "gives the client's data only to the signed-in user of the order's account", :aggregate_failures do
    order = build(:order, :submitted, user_id: 7)

    expect(policy(order, user_id: 7).personal_data?).to be(true)
    expect(policy(order).personal_data?).to be(false)
    expect(policy(build(:order, :submitted)).personal_data?).to be(false)
  end
end
