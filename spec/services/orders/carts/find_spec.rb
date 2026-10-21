# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::Find do
  def owner(user_id: nil, token: nil) = Orders::Carts::Owner.new(user_id:, token:)

  let(:guest_cart) { create(:order) }

  it "opens a guest's cart to anyone with its token" do
    expect(described_class.call(owner(token: guest_cart.token))).to eq(guest_cart)
  end

  it 'finds nothing by the token of a sent order' do
    expect(described_class.call(owner(token: create(:order, :submitted).token))).to be_nil
  end

  it "opens an account's cart only with the session of its user", :aggregate_failures do
    cart = create(:order, user_id: 7)

    expect(described_class.call(owner(user_id: 7, token: cart.token))).to eq(cart)
    expect(described_class.call(owner(token: cart.token))).to be_nil
    expect(described_class.call(owner(user_id: 8, token: cart.token))).to be_nil
  end

  it 'finds the cart of the signed-in user without a token, and nothing for a guest', :aggregate_failures do
    cart = create(:order, user_id: 7)

    expect(described_class.call(owner(user_id: 7))).to eq(cart)
    expect(described_class.call(owner)).to be_nil
  end

  it "takes the guest's cart to an account that has none" do
    described_class.call(owner(user_id: 7, token: guest_cart.token))

    expect(guest_cart.reload.user_id).to eq(7)
  end

  it "opens the guest's cart as it is when the account has a cart", :aggregate_failures do
    create(:order, user_id: 7)

    expect(described_class.call(owner(user_id: 7, token: guest_cart.token))).to eq(guest_cart)
    expect(guest_cart.reload.user_id).to be_nil
  end
end
