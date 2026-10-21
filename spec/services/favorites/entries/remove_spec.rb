# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorites::Entries::Remove do
  let(:user_id) { create(:h24_core_user).id }

  it 'takes a SKU out of the list of the user only', :aggregate_failures do
    favorite = create(:favorite_goods, user_id:)
    others = create(:favorite_goods, goods: favorite.goods)

    described_class.call(Favorites::GOODS, user_id:, target_id: favorite.goods_id)

    expect(Favorite::Goods.exists?(favorite.id)).to be(false)
    expect(Favorite::Goods.exists?(others.id)).to be(true)
  end

  it 'takes out a drugstore the directory no longer shows' do
    favorite = create(:favorite_drugstore, user_id:)
    favorite.drugstore.update!(withdrawn: true)

    described_class.call(Favorites::DRUGSTORES, user_id:, target_id: favorite.drugstore_id)

    expect(Favorite::Drugstore.where(user_id:)).to be_empty
  end

  it 'is no error for a record that is not in the list', :aggregate_failures do
    expect { described_class.call(Favorites::GOODS, user_id:, target_id: create(:catalog_goods).id) }.not_to raise_error
    expect { described_class.call(Favorites::DRUGSTORES, user_id:, target_id: 'nope') }.not_to raise_error
  end
end
