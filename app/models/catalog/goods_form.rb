# frozen_string_literal: true

class Catalog::GoodsForm < ApplicationRecord
  include Catalog::Dictionary

  has_many :goods, class_name: 'Catalog::Goods', foreign_key: :form_id, inverse_of: :form,
                   dependent: :restrict_with_exception
end

# == Schema Information
#
# Table name: catalog_goods_forms
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
