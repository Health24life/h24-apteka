# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Goods::TemperatureMode do
  it_behaves_like 'a catalog dictionary', :catalog_goods_temperature_mode
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
