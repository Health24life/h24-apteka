# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorite::Goods do
  it 'keeps a SKU once per user' do
    favorite = create(:favorite_goods)

    duplicate = -> { create(:favorite_goods, user_id: favorite.user_id, goods: favorite.goods) }

    expect(&duplicate).to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'lets other users keep the same SKU' do
    favorite = create(:favorite_goods)

    expect(create(:favorite_goods, user_id: 7, goods: favorite.goods)).to be_persisted
  end

  it 'goes with the SKU when the SKU is deleted' do
    favorite = create(:favorite_goods)

    favorite.goods.delete

    expect(described_class.exists?(favorite.id)).to be(false)
  end
end
