# frozen_string_literal: true

# The bookings of an account, newest first by the moment of the first consent, a page at a time. Built from what
# Health24 keeps of each booking; the provider is not asked. Whether there is a next page is told without counting
# them all.
class Orders::Bookings::History
  Page = Data.define(:orders, :page, :per_page, :has_more)

  def self.call(user_id:, page: nil, per_page: nil, config: Orders::Bookings.config)
    new(user_id, config).call(page, per_page)
  end

  def initialize(user_id, config)
    @user_id = user_id
    @config = config
  end

  def call(page, per_page)
    page = number(page, 1, Float::INFINITY)
    per_page = number(per_page || @config.history_per_page, 1, @config.history_max_per_page)
    offset = (page - 1) * per_page
    scope = Order.where(user_id: @user_id).where.not(state: 'cart').order(personal_data_consent_at: :desc, id: :desc)
    Page.new(
      orders: scope.offset(offset).limit(per_page),
      page:,
      per_page:,
      has_more: scope.offset(offset + per_page).exists?
    )
  end

  private

  def number(value, min, max)
    number = value.nil? ? min : Integer(value.to_s, exception: false)
    return number if number && number >= min && number <= max

    raise Orders::Carts::Refused.new(:invalid_page, status: :unprocessable_content)
  end
end
