# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::GoodsMeasure do
  it_behaves_like 'a catalog dictionary', :catalog_goods_measure
end

# == Schema Information
#
# Table name: catalog_goods_measures
#
#  id         :bigint           not null, primary key
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
