# frozen_string_literal: true

class Catalog::GoodsPriceGroup < ApplicationRecord
  include Catalog::Dictionary

  has_many :goods, class_name: 'Catalog::Goods', foreign_key: :price_group_id, inverse_of: :price_group,
                   dependent: :restrict_with_exception
end

# == Schema Information
#
# Table name: catalog_goods_price_groups
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
