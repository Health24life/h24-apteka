# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Carts::AddItem do
  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:drugstore) { create(:catalog_drugstore) }
  let(:goods) { create(:catalog_goods) }

  before do
    ProviderLinking.link(provider, drugstore)
    ProviderLinking.link(provider, goods)
    stub_offers_adapter { |store, items| offer_for(store, items, available: 3) }
  end

  def owner(token: nil, user_id: nil) = Orders::Carts::Owner.new(user_id:, token:)

  def add(by = owner, goods_id: goods.id, drugstore_id: drugstore.id, quantity: 1)
    described_class.call(by, goods_id:, drugstore_id:, quantity:)
  end

  # The first look for the cart finds nothing, as if another request made it right after.
  def missed_once
    calls = 0
    allow(Orders::Carts::Find).to receive(:call).and_wrap_original do |original, *args|
      (calls += 1) == 1 ? nil : original.call(*args)
    end
  end

  def linked_drugstore = ProviderLinking.link(provider, create(:catalog_drugstore)).linkable

  describe 'the first item' do
    it 'makes a cart bound to the drugstore and to a provider that serves both', :aggregate_failures do
      result = add(quantity: 2)

      expect(result.created).to be(true)
      expect(result.view.cart).to have_attributes(drugstore:, provider:, user_id: nil, persisted?: true)
      expect(result.view.items.sole).to have_attributes(available?: true, price: BigDecimal('100'))
    end

    it "makes the cart of a signed-in user's account" do
      expect(add(owner(user_id: 9)).view.cart.user_id).to eq(9)
    end

    it 'refuses a drugstore that is hidden, withdrawn or unknown, saving nothing', :aggregate_failures do
      drugstore.update!(hidden: true)

      expect { add }.to be_refused(code: :drugstore_not_found, status: :not_found)
      expect(Order.count).to eq(0)
    end

    it 'refuses a drugstore no provider of the SKU serves' do
      expect { add(drugstore_id: create(:catalog_drugstore).id) }.to be_refused(code: :goods_not_in_drugstore)
    end
  end

  describe 'a cart that is there' do
    let(:cart) { add.view.cart }

    it 'adds to the item of a SKU that is already in it', :aggregate_failures do
      result = add(owner(token: cart.token), quantity: 2)

      expect(result.created).to be(false)
      expect(cart.items.reload.map(&:quantity)).to eq([ 3 ])
    end

    it 'refuses a SKU of another drugstore, leaving the cart as it is', :aggregate_failures do
      expect { add(owner(token: cart.token), drugstore_id: linked_drugstore.id) }
        .to be_refused(code: :cart_drugstore_mismatch, status: :conflict)
      expect(cart.items.reload.size).to eq(1)
    end

    it 'takes the drugstore of the cart when the request leaves it out' do
      add(owner(token: cart.token), drugstore_id: nil)

      expect(cart.items.reload.map(&:quantity)).to eq([ 2 ])
    end

    it 'refuses a SKU the provider of the cart does not serve, not asking it' do
      unlinked = create(:catalog_goods)

      expect { add(owner(token: cart.token), goods_id: unlinked.id) }
        .to be_refused(code: :goods_not_in_drugstore, status: :unprocessable_content)
    end

    it 'refuses packs that would not fit the item', :aggregate_failures do
      cart.items.sole.update!(quantity: Order::Item::MAX_QUANTITY - 1)

      expect { add(owner(token: cart.token)) }.to be_refused(code: :invalid_quantity)
      expect(cart.items.reload.sole.quantity).to eq(Order::Item::MAX_QUANTITY - 1)
    end

    it "puts the SKU in the user's cart that another request made meanwhile", :aggregate_failures do
      made = add(owner(user_id: 9)).view.cart
      missed_once

      expect(add(owner(user_id: 9))).to have_attributes(created: false)
      expect(made.items.reload.map(&:quantity)).to eq([ 2 ])
    end

    it 'puts a second SKU in an item of its own' do
      second = create(:catalog_goods)
      ProviderLinking.link(provider, second)

      add(owner(token: cart.token), goods_id: second.id)

      expect(cart.items.reload.map(&:goods)).to contain_exactly(goods, second)
    end
  end

  describe 'the live check' do
    it 'refuses a SKU the drugstore does not have' do
      stub_offers_adapter { |store, items| offer_for(store, items, fulfilled: false, available: 0) }

      expect { add }.to be_refused(code: :goods_not_in_drugstore, status: :unprocessable_content)
    end

    it 'tells how many packs the drugstore has when it does not cover all those asked' do
      stub_offers_adapter { |store, items| offer_for(store, items, fulfilled: false, available: 2) }

      expect { add(quantity: 4) }.to be_refused(code: :quantity_exceeds_stock, details: { available_quantity: 2 })
    end

    it 'refuses more packs than the drugstore has, telling how many it has, and saves nothing', :aggregate_failures do
      expect { add(quantity: 4) }.to be_refused(code: :quantity_exceeds_stock, details: { available_quantity: 3 })
      expect(Order.count).to eq(0)
    end

    it 'counts the packs already in the cart' do
      token = add(quantity: 2).view.cart.token

      expect { add(owner(token:), quantity: 2) }.to be_refused(code: :quantity_exceeds_stock)
    end

    it 'is busy, with the wait, when the provider refused for its limit' do
      stub_offers_adapter { Orders::Offers::Failure.new(reason: :rate_limited, retry_after: 9) }

      expect { add }.to be_refused(code: :cart_check_busy, status: :service_unavailable, retry_after: 9)
    end

    it 'cannot be made when the provider tells nothing, and saves nothing', :aggregate_failures do
      stub_offers_adapter { |store, _items| Orders::Offers::DrugstoreOffer.unknown(store.id) }

      expect { add }.to be_refused(code: :cart_check_unavailable)
      expect(Order.count).to eq(0)
    end
  end

  it 'refuses a SKU that is hidden, withdrawn or unknown' do
    goods.update!(hidden: true)

    expect { add }.to be_refused(code: :goods_not_found, status: :not_found)
  end
end
