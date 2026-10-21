# frozen_string_literal: true

# A booking in the history of an account: its numbers, state and the partner's status, when it was booked, the
# drugstore as it was then and the total. No client's data and no items, only how many there are.
class Orders::Bookings::HistoryBlueprint < Blueprinter::Base
  fields :token, :own_number, :state

  field(:customer_number) { |order| order.provider_payload['order_number_for_customer'] }
  field(:status) do |order|
    status = Orders::PartnerStatuses::Describe.call(order)
    { title: status.title, comment: status.comment, known: status.known, updated_at: order.status_synced_at }
  end
  field :personal_data_consent_at, name: :booked_at
  field(:drugstore) { |order| { id: order.drugstore_id, name: order.drugstore_name, address: order.drugstore_address } }
  field(:items_count, preload: :items) { |order| order.items.size }
  field(:total, preload: :items) do |order|
    Orders::Carts::CartBlueprint::MONEY.call(order.items.sum { it.total || 0 })
  end
end
