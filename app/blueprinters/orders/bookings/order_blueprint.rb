# frozen_string_literal: true

# A sent order, as it was when it was sent: the drugstore and the items with their prices, its numbers and the
# partner's status as the partner wrote it. The client's data comes only when the render is told `personal_data: true`,
# which OrderPolicy decides: the token is also the link the order is shared by.
class Orders::Bookings::OrderBlueprint < Blueprinter::Base
  MONEY = Orders::Carts::CartBlueprint::MONEY
  PERSONAL_DATA = ->(_name, _order, options) { options[:personal_data] == true }

  fields :token, :own_number, :state

  field(:customer_number) { |order| order.provider_payload['order_number_for_customer'] }
  field(:status) do |order|
    status = Orders::PartnerStatuses::Describe.call(order)
    { title: status.title, comment: status.comment, known: status.known, updated_at: order.status_synced_at }
  end
  field(:customer, if: PERSONAL_DATA) do |order|
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
  field(:total, preload: :items) { |order| MONEY.call(order.items.sum { it.total || 0 }) }

  association :items, blueprint: Orders::Bookings::ItemBlueprint do |order, _options|
    order.items.sort_by(&:id)
  end
end
