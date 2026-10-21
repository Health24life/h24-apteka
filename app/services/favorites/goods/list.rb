# frozen_string_literal: true

# «Мої товари»: the SKU of the user's list, the last added first, each with the moment it was added as `added_at`. The
# provider is not asked: a price belongs to a drugstore.
class Favorites::Goods::List
  def self.call(user_id:)
    added = Favorite::Goods.arel_table
    Catalog::Goods
      .joins(:favorites)
      .where(favorite_goods: { user_id: })
      .select(Catalog::Goods.arel_table[Arel.star], added[:created_at].as('added_at'))
      .order(added[:created_at].desc, added[:id].desc)
  end
end
