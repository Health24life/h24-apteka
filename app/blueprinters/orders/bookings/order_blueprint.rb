# frozen_string_literal: true

# A sent order, as it was when it was sent: the drugstore and the items with their prices, its numbers and the
# partner's status as the partner wrote it. The owner's view has the client's data and the token; the view of a shared
# link has neither.
class Orders::Bookings::OrderBlueprint < Blueprinter::Base
  MONEY = Orders::Carts::CartBlueprint::MONEY
  OWNER = ->(_name, _order, options) { !options[:shared] }

  fields :share_token, :own_number, :state

  field(:token, if: OWNER)
  field(:customer_number) { |order| order.provider_payload['order_number_for_customer'] }
  field(:status) do |order|
    status = Orders::PartnerStatuses::Describe.call(order)
    { title: status.title, comment: status.comment, known: status.known, updated_at: order.status_synced_at }
  end
  field(:customer, if: OWNER) do |order|
    {
      first_name: order.customer_first_name,
      last_name: order.customer_last_name,
      middle_name: order.customer_middle_name,
      phone_number: order.customer_phone_number,
      email: order.customer_email
    }
  end
  field(:drugstore) do |order|
    {
      id: order.drugstore_id,
      name: order.drugstore_name,
      address: order.drugstore_address,
      phone: order.drugstore_phone
    }
  end
  field(:items) do |order|
    order.items.order(:id).map do |item|
      {
        goods_id: item.goods_id,
        name: item.name,
        quantity: item.quantity.to_i,
        price: MONEY.call(item.price),
        total: MONEY.call(item.total)
      }
    end
  end
  field(:total) { |order| MONEY.call(order.items.sum { it.total || 0 }) }
end
