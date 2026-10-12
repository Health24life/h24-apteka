# frozen_string_literal: true

class Catalog::Goods::Form < ApplicationRecord
  include Catalog::Dictionary

  has_many :goods, class_name: 'Catalog::Goods', inverse_of: :form,
                   dependent: :restrict_with_exception
end

# == Schema Information
#
# Table name: catalog_goods_forms
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
