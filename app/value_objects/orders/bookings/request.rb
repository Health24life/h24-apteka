# frozen_string_literal: true

# What the front sends to book a cart: the goods with the quantities and the prices the user agreed to, the client and
# the consent. A value that cannot be booked is refused before anything is asked of the provider.
class Orders::Bookings::Request < Data.define(:goods, :customer, :register_account)
  NAME_LENGTH = Order::NAME_LENGTH
  CUSTOMER_FIELDS = %w[first_name last_name middle_name phone_number email].freeze
  NAMES = %w[first_name last_name middle_name].freeze

  # The quantity and the agreed price of a SKU of the cart, by the SKU's id.
  class Line < Data.define(:quantity, :price); end

  def self.from(body)
    refuse(:personal_data_consent_required) unless body['personal_data_consent'] == true

    new(
      goods: goods(body['goods']),
      customer: customer(body['customer']),
      register_account: body['register_account'] == true
    )
  end

  # Goods that do not read as the lines of a cart cannot be those of the cart.
  def self.goods(value)
    # @type var entries: Array[untyped]
    entries = value.is_a?(Array) ? value : []
    lines = entries.map { line(it) }
    refuse(:cart_changed, :conflict) if lines.empty? || lines.include?(nil)

    lines.compact.to_h
  end

  def self.line(entry)
    return unless entry.is_a?(Hash)

    goods_id = entry['goods_id']
    quantity = entry['quantity']
    price = BigDecimal(entry['price'].to_s, exception: false)
    [ goods_id, Line.new(quantity:, price:) ] if goods_id.is_a?(Integer) && quantity.is_a?(Integer) && price
  end

  def self.customer(value)
    # @type var given: Hash[String, untyped]
    given = value.is_a?(Hash) ? value : {}
    fields = given.slice(*CUSTOMER_FIELDS).transform_values { it.to_s.squish.presence }
    phone = Orders::Customers::PhoneNormalizer.call(fields['phone_number']) || invalid!('phone_number')
    check_names!(fields)
    email = fields['email']
    invalid!('email') if email && !email.match?(URI::MailTo::EMAIL_REGEXP)

    fields.merge('phone_number' => phone)
  end

  def self.check_names!(fields)
    invalid!('first_name') unless fields['first_name']
    NAMES.each { invalid!(it) if fields[it].to_s.length > NAME_LENGTH }
  end

  def self.invalid!(field) = refuse(:invalid_customer, details: { field: })

  def self.refuse(code, status = :unprocessable_content, details: nil)
    raise Orders::Carts::Refused.new(code, status:, details:)
  end

  # Whether the cart holds these SKUs in these quantities, and nothing else.
  def matches?(items) = goods.transform_values(&:quantity) == items.to_h { [ it.goods_id, it.quantity.to_i ] }
end
