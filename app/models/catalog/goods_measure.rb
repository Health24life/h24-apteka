# frozen_string_literal: true

class Catalog::GoodsMeasure < ApplicationRecord
  include Catalog::Dictionary

  has_many :goods, class_name: 'Catalog::Goods', foreign_key: :measure_id, inverse_of: :measure,
                   dependent: :restrict_with_exception
end

# == Schema Information
#
# Table name: catalog_goods_measures
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
