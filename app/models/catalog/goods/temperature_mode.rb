# frozen_string_literal: true

class Catalog::Goods::TemperatureMode < ApplicationRecord
  include Catalog::Dictionary

  has_many :goods, class_name: 'Catalog::Goods', inverse_of: :temperature_mode,
                   dependent: :restrict_with_exception
end

# == Schema Information
#
# Table name: catalog_goods_temperature_modes
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
