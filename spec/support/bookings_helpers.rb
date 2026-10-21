# frozen_string_literal: true

module BookingsHelpers
  # A provider that takes orders with what `answers[:submit]` holds and finds earlier ones with what `answers[:found]`
  # holds (a value, or a block given the time it looks since). The own numbers it was sent are kept in `submitted`, the
  # phones it looked earlier orders up by in `looked_up`.
  class FakeBookings
    class << self
      attr_accessor :answers, :submitted, :cancelled, :looked_up
    end

    attr_reader :provider

    def initialize(provider:, **) = @provider = provider

    def submit(order)
      self.class.submitted << order.own_number
      self.class.answers[:submit]
    end

    def status(_order) = self.class.answers[:submit]

    def cancel(_order, reason:)
      self.class.cancelled << reason
      self.class.answers.fetch(:cancel, true)
    end

    def find_submitted(_order, since:, phone:)
      self.class.looked_up << phone
      found = self.class.answers[:found]
      found.respond_to?(:call) ? found.call(since) : found
    end
  end

  def stub_bookings_adapter(submit: nil, found: nil, cancel: true)
    adapter = Class.new(FakeBookings)
    adapter.answers = { submit: submit || partner_order, found:, cancel: }
    adapter.submitted = []
    adapter.cancelled = []
    adapter.looked_up = []
    stub_const('Orders::Bookings::Adapters::BY_CODE', { 'pharmapoint' => adapter })
    adapter
  end

  def partner_order(number: 'PB-35-PT-H5', status_name: 'created')
    Pharmapoint::PartnerOrder.new(
      number:,
      customer_number: '123456',
      status_name:,
      status_comment: 'Передан в обработку',
      cancel_reason: nil,
      progress: { 'step' => 1 },
      created_at: Time.current,
      updated_at: Time.current,
      drugstore_external_id: nil,
      lines: [],
      record: { 'order_number' => number, 'order_number_for_customer' => '123456' }
    )
  end

  def use_booking_config(drugstore_ids:)
    config = Orders::Bookings::Config.new.configure { it.drugstore_ids = drugstore_ids }
    allow(Orders::Bookings).to receive(:config).and_return(config)
  end

  def booking_body(cart, price: '100', consent: true, customer: {})
    {
      'goods' => cart.items.map { { 'goods_id' => it.goods_id, 'quantity' => it.quantity.to_i, 'price' => price } },
      'customer' => { 'first_name' => 'Олена', 'phone_number' => '+380 67 123 45 67' }.merge(customer),
      'personal_data_consent' => consent,
      'register_account' => true
    }
  end
end

RSpec.configure { it.include BookingsHelpers }
