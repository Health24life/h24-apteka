# frozen_string_literal: true

# «Мої аптеки»: the drugstores of the user's list, the last added first, each with the moment it was added as
# `added_at`. The provider is not asked.
class Favorites::Drugstores::List
  def self.call(user_id:)
    added = Favorite::Drugstore.arel_table
    Catalog::Drugstore
      .joins(:favorites)
      .where(favorite_drugstores: { user_id: })
      .select(Catalog::Drugstore.arel_table[Arel.star], added[:created_at].as('added_at'))
      .order(added[:created_at].desc, added[:id].desc)
  end
end
