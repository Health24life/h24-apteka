# frozen_string_literal: true

# Puts a SKU in the cart of the one who asks. Without a token, the first one makes the cart, bound to the drugstore
# picked and to a provider that serves both, unless the signed-in user has a cart already; with the token of a cart,
# the SKU goes to that cart, and only for its drugstore, which may then be left out. A SKU already in the cart adds to
# its item. Every change is checked live against what the drugstore has, and nothing is saved when the check refuses or
# cannot be made.
class Orders::Carts::AddItem
  Result = Data.define(:view, :created)

  def self.call(owner, goods_id:, drugstore_id:, quantity:) = new(owner, goods_id, drugstore_id, quantity).call

  def initialize(owner, goods_id, drugstore_id, quantity)
    @owner = owner
    @goods_id = goods_id
    @drugstore_id = drugstore_id
    @quantity = quantity
  end

  def call
    goods = Orders::Offers::Nearby.find_goods(@goods_id) || refuse(:goods_not_found, :not_found)
    cart = Orders::Carts::Find.call(@owner)
    return add(Orders::Carts::Opening.tidy(cart), goods) if cart
    return first(goods) unless @owner.token

    Orders::Carts::Opening.not_found
  end

  private

  def add(opened, goods)
    cart = opened.cart
    refuse(:cart_drugstore_mismatch, :conflict) if other_drugstore?(cart)
    refuse(:goods_not_in_drugstore, :unprocessable_content) unless goods.provider_links.exists?(provider: cart.provider)

    item = bumped(cart, goods)
    offer = check(cart, goods, item.quantity)
    item.save!
    Result.new(view: Orders::Carts::View.of(cart, offer, removed: opened.removed), created: false)
  end

  def create(goods)
    drugstore = Catalog::Drugstore.find_by(id: @drugstore_id, hidden: false, withdrawn: false) ||
                refuse(:drugstore_not_found, :not_found)
    provider = provider_of(drugstore, goods) || refuse(:goods_not_in_drugstore, :unprocessable_content)
    cart = Order.new(drugstore:, provider:, user_id: @owner.user_id)
    cart.items.build(goods:, quantity: @quantity)
    offer = check(cart, goods, @quantity)
    cart.save!
    Result.new(view: Orders::Carts::View.of(cart, offer), created: true)
  end

  # Another request of the same user may make their cart first; the SKU then goes there.
  def first(goods)
    create(goods)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    raise unless @owner.user_id && cart_taken?(e)

    add(Orders::Carts::Opening.call(@owner), goods)
  end

  def cart_taken?(error)
    !error.is_a?(ActiveRecord::RecordInvalid) || error.record.errors.of_kind?(:user_id, :taken)
  end

  # The item of the SKU with the packs added, a new one when the cart has none; not saved yet.
  def bumped(cart, goods)
    item = cart.items.to_a.find { it.goods_id == goods.id } || cart.items.build(goods:, quantity: 0)
    item.quantity += @quantity
    refuse(:invalid_quantity, :unprocessable_content) if item.quantity >= Order::Item::MAX_QUANTITY
    item
  end

  def other_drugstore?(cart) = !@drugstore_id.nil? && cart.drugstore_id.to_s != @drugstore_id.to_s

  # An enabled provider with an adapter that serves both the drugstore and the SKU.
  def provider_of(drugstore, goods)
    drugstore.providers.enabled.where(id: goods.providers.select(:id)).order(:id)
      .find { Orders::Offers::Adapters::BY_CODE.key?(it.code) }
  end

  def check(cart, goods, quantity) = Orders::Carts::Check.call(cart, goods:, quantity:, user_id: @owner.user_id)

  def refuse(code, status) = raise(Orders::Carts::Refused.new(code, status:))
end
