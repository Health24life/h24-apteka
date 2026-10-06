# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::GoodsForm do
  it_behaves_like 'a catalog dictionary', :catalog_goods_form
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
