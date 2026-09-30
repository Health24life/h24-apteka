# frozen_string_literal: true

class Catalog::GoodsRestriction < ApplicationRecord
  include Catalog::Dictionary
end

# == Schema Information
#
# Table name: catalog_goods_restrictions
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
