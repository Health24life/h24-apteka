# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::GoodsRestriction do
  it_behaves_like 'a catalog dictionary', :catalog_goods_restriction
end

# == Schema Information
#
# Table name: catalog_goods_restrictions
#
#  id                           :bigint           not null, primary key
#  name                         :string
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  catalog_goods_restriction_id :bigint           not null
#
