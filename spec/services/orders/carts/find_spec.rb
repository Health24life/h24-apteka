# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::Find do
  def owner(user_id: nil, token: nil) = Orders::Carts::Owner.new(user_id:, token:)

  let(:guest_cart) { create(:order) }

  it "finds a guest's cart by its token" do
    expect(described_class.call(owner(token: guest_cart.token))).to eq(guest_cart)
  end

  it 'finds nothing by the token of a sent order or of a cart that went to an account', :aggregate_failures do
    expect(described_class.call(owner(token: create(:order, :submitted).token))).to be_nil
    expect(described_class.call(owner(token: create(:order, user_id: 5).token))).to be_nil
  end

  it "finds an account's cart by the user" do
    cart = create(:order, user_id: 7)

    expect(described_class.call(owner(user_id: 7))).to eq(cart)
  end

  it "gives the guest's cart to an account that has none", :aggregate_failures do
    found = described_class.call(owner(user_id: 7, token: guest_cart.token))

    expect(found).to eq(guest_cart)
    expect(guest_cart.reload.user_id).to eq(7)
  end

  it "keeps the account's cart and leaves the guest's one as it is when the account has a cart", :aggregate_failures do
    account_cart = create(:order, user_id: 7)

    expect(described_class.call(owner(user_id: 7, token: guest_cart.token))).to eq(account_cart)
    expect(guest_cart.reload.user_id).to be_nil
  end
end
