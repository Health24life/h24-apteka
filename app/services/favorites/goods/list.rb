# frozen_string_literal: true

# «Мої товари»: the SKU of the user's list, the last added first, with the static data of their cards. No prices: a
# price belongs to a drugstore, and the provider is not asked.
class Favorites::Goods::List
  class Row < Data.define(:goods, :added_at)
    def available? = goods.shown?
  end

  def self.call(user_id:)
    Favorite::Goods
      .where(user_id:)
      .includes(goods: [ :translations, { goods_group: %i[producer goods_name] } ])
      .order(created_at: :desc, id: :desc)
      .map { Row.new(goods: it.goods, added_at: it.created_at) }
  end
end
