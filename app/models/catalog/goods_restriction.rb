# frozen_string_literal: true

class Catalog::GoodsRestriction < ApplicationRecord
  include Catalog::Dictionary

  Catalog::Goods::RESTRICTIONS.each do |restriction|
    has_many :"#{restriction}_goods", class_name: 'Catalog::Goods', foreign_key: :"#{restriction}_id",
                                      inverse_of: restriction, dependent: :restrict_with_exception
  end
end

# == Schema Information
#
# Table name: catalog_goods_restrictions
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
