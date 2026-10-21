# frozen_string_literal: true

# Orders as the partner answers them on making one, on reading one by its number and in the history of a client. The
# partner's times carry no zone and are read as Kyiv time; the original strings stay in the record.
class Pharmapoint::Readers::PartnerOrders
  include Pharmapoint::Readers::Base

  ZONE = 'Europe/Kyiv'

  def self.one(body) = new.one(body)

  def self.many(body) = new.many(body)

  def one(body) = order(envelope(body)) || raise(Pharmapoint::InvalidResponse, 'the answer has no order')

  def many(body) = list(envelope(body)).filter_map { order(it) }

  private

  def order(record)
    return unless record.is_a?(Hash)

    number = text_at(record, 'order_number')
    return unless number

    Pharmapoint::PartnerOrder.new(
      number:,
      customer_number: text_at(record, 'order_number_for_customer'),
      status_name: text_at(record, 'status_name'),
      status_comment: text_at(record, 'status_comment'),
      cancel_reason: text_at(record, 'cancel_reason'),
      progress: hash_at(record, 'progress'),
      created_at: time(record['created_at']),
      updated_at: time(record['updated_at']),
      drugstore_external_id: id_at(record, 'drugstore_id'),
      lines: lines(record),
      record:
    )
  end

  def lines(record)
    list_at(record, 'goods').filter_map do |line|
      next unless line.is_a?(Hash)

      external_id = id_at(line, 'goods_id')
      quantity = float_at(line, 'quantity')
      if external_id && quantity
        Pharmapoint::PartnerOrderLine.new(
          goods_external_id: external_id,
          quantity: BigDecimal(quantity.to_s)
        )
      end
    end
  end

  def time(value)
    string = text(value)
    string && ActiveSupport::TimeZone.new(ZONE).parse(string)
  rescue ArgumentError
    nil
  end
end
