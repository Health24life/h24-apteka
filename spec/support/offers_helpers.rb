# frozen_string_literal: true

module OffersHelpers
  # Makes every provider answer the live offers with what the block gives for the drugstore and the items asked, so a
  # spec of the cart or of the pharmacy list needs no partner.
  def stub_offers_adapter(&answer)
    adapter = Class.new do
      class << self
        attr_accessor :answer
      end

      attr_reader :provider

      def initialize(provider:, **) = @provider = provider

      def in_drugstore(drugstore, items, **) = self.class.answer.call(drugstore, items)
    end
    adapter.answer = answer
    stub_const('Orders::Offers::Adapters::BY_CODE', { 'pharmapoint' => adapter })
  end

  # A drugstore's answer that covers every item asked, with the price and the packs given per SKU.
  def offer_for(drugstore, items, price: '100', available: 5, fulfilled: true)
    lines = items.map do |item|
      Orders::Offers::Line.new(
        goods_id: item.goods.id,
        fulfilled:,
        price: BigDecimal(price),
        available_quantity: available
      )
    end
    Orders::Offers::DrugstoreOffer.unknown(drugstore.id).with(open_now: true, lines:)
  end
end

RSpec.configure { it.include OffersHelpers }
