# frozen_string_literal: true

# Takes down what the order is about at the moment it is sent, so later changes of the catalog do not change it: the
# drugstore, and every item with its name, producer, form, the provider's id and the price confirmed live. Pick-up paid
# in the drugstore is the only way for now. Nothing is saved here.
class Orders::Bookings::Snapshot
  def self.call(order, offer) = new(order, offer).call

  def initialize(order, offer)
    @order = order
    @offer = offer
  end

  def call
    drugstore(@order.drugstore)
    @order.delivery ||= Order::Delivery.new(delivery_type_code: 'pick_up')
    @order.payment ||= Order::Payment.new(payment_type_code: 'cash_in_store')
    @order.items.each { item(it) }
    @order
  end

  private

  def drugstore(drugstore)
    @order.assign_attributes(
      drugstore_name: drugstore.name || drugstore.drugstore_legal_entity_name,
      drugstore_address: drugstore.address&.address,
      drugstore_phone: drugstore.phone || drugstore.mobile_phone
    )
  end

  def item(item)
    goods = item.goods || return
    price = @offer.line_for(goods.id)&.price
    item.assign_attributes(
      name: goods.name,
      producer: goods.producer&.name,
      release_form: goods.release_form,
      image_paths: goods.image_paths,
      provider_goods_external_id: goods.provider_ref(@order.provider),
      price:,
      total: price && (price * item.quantity)
    )
  end
end
