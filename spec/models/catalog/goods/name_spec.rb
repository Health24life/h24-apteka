# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Goods::Name do
  it { is_expected.to validate_presence_of(:name) }

  it 'refuses to delete a name that a group uses' do
    name = create(:catalog_goods_name)
    create(:catalog_goods_group, goods_name: name)

    expect { name.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

# == Schema Information
#
# Table name: catalog_goods_names
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
