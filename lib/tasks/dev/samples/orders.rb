# frozen_string_literal: true

# Carts of guests and orders sent to the provider in every state, with their customers, items, delivery and payment.
module DevSamples::Orders
  CARTS = 15
  SENT = 55
  CUSTOMERS = [ %w[Олена Петренко], %w[Тарас Коваль], %w[Ірина Шевчук], %w[Андрій Мельник], %w[Марія Бондар],
                %w[Олег Ткаченко], %w[Наталія Кравчук], %w[Сергій Литвиненко] ].freeze
  STATUSES = [
    [ 'Нове', nil ], [ 'Підтверджене', 'Аптека зібрала замовлення' ], [ 'Готове до видачі', 'Чекаємо до 21:00' ],
    [ 'Видане', nil ], [ 'Скасоване', 'Немає в наявності' ]
  ].freeze

  module_function

  def call(provider)
    drugstores = Catalog::Drugstore.where(hidden: false, withdrawn: false).order(:id).to_a.cycle
    goods = Catalog::Goods.shown.order(:id).to_a
    (CARTS - Order.cart.count).times { cart(provider, drugstores.next, goods) }
    SENT.times { |number| sent(provider, drugstores.next, goods, number) }
  end

  def cart(provider, drugstore, goods)
    order = Order.new(provider:, drugstore:)
    goods.sample(rand(1..3)).each { order.items.build(goods: it, quantity: rand(1..3)) }
    order.save!
  end

  def sent(provider, drugstore, goods, number)
    own_number = format('H24-%010d', number + 1)
    return if Order.exists?(own_number:)

    order = Order.new(provider:, drugstore:, own_number:, created_at: number.hours.ago, **pick_up,
                      **customer(number), **status(number, drugstore))
    goods.sample(rand(1..4)).each { order.items.build(item(provider, it)) }
    order.save!
  end

  def pick_up
    { delivery: Order::Delivery.new(delivery_type_code: 'pick_up'),
      payment: Order::Payment.new(payment_type_code: 'cash_in_store') }
  end

  def customer(number)
    first, last = CUSTOMERS[number % CUSTOMERS.size]
    { customer_first_name: first, customer_last_name: last, customer_phone_number: format('3805012%05d', number),
      customer_email: "client#{number}@example.com", personal_data_consent_at: number.hours.ago }
  end

  # Every ninth order never reached the provider, so it has neither its number nor its status.
  def status(number, drugstore)
    snapshot = { provider_drugstore_external_id: drugstore.ext_drugstore_id, drugstore_name: drugstore.name,
                 drugstore_address: drugstore.address&.address, drugstore_phone: drugstore.phone }
    return snapshot.merge(state: 'submission_failed') if (number % 9) == 8

    name, comment = STATUSES[number % STATUSES.size]
    snapshot.merge(state: 'submitted', provider_order_number: "PP#{100_000 + number}", status_name: name,
                   status_comment: comment, provider_updated_at: number.hours.ago, status_synced_at: 10.minutes.ago)
  end

  def item(provider, sku)
    quantity = rand(1..3)
    price = rand(4_000..90_000)
    { goods: sku, quantity:, name: sku.name_uk, producer: sku.goods_group.producer&.name,
      release_form: sku.release_form, price_cents: price, total_cents: price * quantity,
      provider_goods_external_id: sku.provider_ref(provider) }
  end
end
