# frozen_string_literal: true

module CartHelpers
  # The cart refused the change with these attributes: code, status, details, retry_after.
  def be_refused(**attributes)
    raise_error(an_instance_of(Orders::Carts::Refused).and(having_attributes(**attributes)))
  end

  # Pharmapoint answers on one drugstore that it covers every SKU asked, at 162.50 a pack, with the packs given.
  def stub_drugstore_offers(available: 3, fulfilled: true)
    stub_request(:post, pharmapoint_url('order/get-drugstore-for-order-goods'))
      .with(query: hash_including({}))
      .to_return { |request| pharmapoint_answer(nil, body: drugstore_offers(request, available:, fulfilled:)) }
  end

  def drugstore_offers(request, available:, fulfilled:)
    sent = JSON.parse(request.body)
    goods = sent['goods'].map do |line|
      { goods_id: line['goods_id'], is_fulfilled: fulfilled, drugstore_price: 162.5, quantity: available }
    end
    { data: [ { id: sent['drugstore_id'], order: { goods: } } ] }.to_json
  end

  # A guest's cart in the drugstore with one pack of the SKU.
  def guest_cart(provider:, drugstore:, goods:)
    cart = FactoryBot.build(:order, provider:, drugstore:, items_count: 0)
    cart.items.build(goods:, quantity: 1)
    cart.save!
    cart
  end
end

RSpec.configure { it.include CartHelpers }
