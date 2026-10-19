# frozen_string_literal: true

# The live answer on goods in drugstores: for every drugstore, its distance, today's hours and what it has of each line.
# Only the in-drugstore price is read; the online one is never shown. The static data of a drugstore comes from the
# directory, so it is not read here.
class Pharmapoint::Readers::Offers
  include Pharmapoint::Readers::Base

  def self.call(body) = new.many(body)

  def many(body) = list(envelope(body)).filter_map { offer(it) }

  private

  def offer(record)
    return unless record.is_a?(Hash)

    external_id = id_at(record, 'id')
    return unless external_id

    Pharmapoint::Offer.new(
      drugstore_external_id: external_id,
      distance: int_at(record, 'distance'),
      today_hours: today_hours(hash_at(record, 'working_hours')),
      items: items(record['order'])
    )
  end

  def today_hours(record)
    Pharmapoint::TodayHours.new(
      from: text_at(record, 'from'),
      to: text_at(record, 'to'),
      open: record.key?('is_open') ? affirmative_at?(record, 'is_open') : nil,
      round_the_clock: affirmative_at?(record, 'is_24h')
    )
  end

  def items(order)
    return unless order.is_a?(Hash)

    list_at(order, 'goods').filter_map { item(it) }
  end

  def item(record)
    return unless record.is_a?(Hash)

    external_id = id_at(record, 'goods_id')
    return unless external_id

    Pharmapoint::OfferItem.new(
      goods_external_id: external_id,
      fulfilled: affirmative_at?(record, 'is_fulfilled'),
      price: money(record['drugstore_price']),
      quantity: decimal(record['quantity'])
    )
  end

  # Prices come as floats such as 80.989999999999995; their text form is what the partner meant.
  def money(value)
    number = float(value)
    BigDecimal(number.round(2).to_s) if number
  end

  def decimal(value)
    number = float(value)
    BigDecimal(number.to_s) if number
  end
end
