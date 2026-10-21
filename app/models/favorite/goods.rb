# frozen_string_literal: true

# A SKU a user keeps in «Мої товари». It stays when the SKU is hidden or withdrawn later; the database drops it with the
# SKU. The core lives in another database, so the user has no foreign key.
class Favorite::Goods < ApplicationRecord
  belongs_to :goods, class_name: 'Catalog::Goods', inverse_of: :favorites
end

# == Schema Information
#
# Table name: favorite_goods
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  goods_id   :bigint           not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_favorite_goods_on_goods_id              (goods_id)
#  index_favorite_goods_on_user_id_and_goods_id  (user_id,goods_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (goods_id => catalog_goods.id) ON DELETE => cascade
#
