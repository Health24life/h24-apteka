# frozen_string_literal: true

class Catalog::GoodsForm < ApplicationRecord
  include Catalog::Dictionary
end

# == Schema Information
#
# Table name: catalog_goods_forms
#
#  id                    :bigint           not null, primary key
#  name                  :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  catalog_goods_form_id :bigint           not null
#
