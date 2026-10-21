# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorites::Entries::Add do
  let(:user_id) { 42 }

  def add(target, kind: Favorites::GOODS) = described_class.call(kind, user_id:, target_id: target.id)

  def refused_with(code, status, details: nil)
    raise_error(Favorites::Refused) { |error| expect([ error.code, error.status, error.details ]).to eq([ code, status, details ]) }
  end

  def fill(kind, count)
    create_list(kind == Favorites::GOODS ? :favorite_goods : :favorite_drugstore, count, user_id:)
  end

  it 'puts a SKU in the list of the user' do
    goods = create(:catalog_goods)

    add(goods)

    expect(Favorite::Goods.where(user_id:).pluck(:goods_id)).to eq([ goods.id ])
  end

  it 'puts a drugstore in the list of the user' do
    drugstore = create(:catalog_drugstore)

    add(drugstore, kind: Favorites::DRUGSTORES)

    expect(Favorite::Drugstore.where(user_id:).pluck(:drugstore_id)).to eq([ drugstore.id ])
  end

  it 'keeps a record added again once, in its place' do
    favorite = create(:favorite_goods, user_id:, created_at: 1.day.ago)

    add(favorite.goods)

    expect(Favorite::Goods.where(user_id:).pluck(:id, :created_at)).to eq([ [ favorite.id, favorite.created_at ] ])
  end

  it 'keeps another pack of the same trade name as a record of its own' do
    favorite = create(:favorite_goods, user_id:)
    other_pack = create(:catalog_goods, goods_group: favorite.goods.goods_group)

    add(other_pack)

    expect(Favorite::Goods.where(user_id:).pluck(:goods_id)).to contain_exactly(favorite.goods_id, other_pack.id)
  end

  it 'refuses a SKU the catalog does not show, alone or with its group', :aggregate_failures do
    hidden_group = create(:catalog_goods_group, hidden: true)
    withdrawn_group = create(:catalog_goods_group, withdrawn: true)
    [
      create(:catalog_goods, hidden: true),
      create(:catalog_goods, withdrawn: true),
      create(:catalog_goods, goods_group: hidden_group),
      create(:catalog_goods, goods_group: withdrawn_group)
    ].each { |goods| expect { add(goods) }.to refused_with(:goods_not_found, :not_found) }

    expect(Favorite::Goods.count).to eq(0)
  end

  it 'refuses a drugstore the directory does not show', :aggregate_failures do
    [ create(:catalog_drugstore, hidden: true), create(:catalog_drugstore, withdrawn: true) ].each do |drugstore|
      expect { add(drugstore, kind: Favorites::DRUGSTORES) }.to refused_with(:drugstore_not_found, :not_found)
    end

    expect(Favorite::Drugstore.count).to eq(0)
  end

  it 'refuses an id the catalog does not have' do
    add_unknown = -> { described_class.call(Favorites::GOODS, user_id:, target_id: 'nope') }

    expect(&add_unknown).to refused_with(:goods_not_found, :not_found)
  end

  describe 'limit' do
    before { stub_const('Favorites::LIMIT', 3) }

    it 'refuses a new record when the list is full' do
      fill(Favorites::GOODS, 3)
      goods = create(:catalog_goods)

      expect { add(goods) }.to refused_with(:favorites_limit_reached, :unprocessable_content, details: { limit: 3 })
    end

    it 'takes a new record while there is room' do
      fill(Favorites::GOODS, 2)

      expect { add(create(:catalog_goods)) }.to change { Favorite::Goods.where(user_id:).count }.to(3)
    end

    it 'takes a record already in a full list again' do
      favorite = fill(Favorites::DRUGSTORES, 3).first

      expect { add(favorite.drugstore, kind: Favorites::DRUGSTORES) }.not_to raise_error
    end

    it 'counts the lists apart' do
      fill(Favorites::GOODS, 3)

      expect { add(create(:catalog_drugstore), kind: Favorites::DRUGSTORES) }.not_to raise_error
    end

    it 'counts unavailable records too' do
      fill(Favorites::GOODS, 3).first.goods.update!(hidden: true)

      goods = create(:catalog_goods)

      expect { add(goods) }.to refused_with(:favorites_limit_reached, :unprocessable_content, details: { limit: 3 })
    end

    it 'counts the records of the user only' do
      create_list(:favorite_goods, 3, user_id: 7)

      expect { add(create(:catalog_goods)) }.not_to raise_error
    end
  end
end
