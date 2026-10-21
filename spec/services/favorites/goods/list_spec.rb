# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorites::Goods::List do
  let(:user_id) { 42 }

  it 'lists the SKU of the user, the last added first' do
    older = create(:favorite_goods, user_id:, created_at: 2.days.ago)
    newer = create(:favorite_goods, user_id:, created_at: 1.day.ago)
    create(:favorite_goods, user_id: 7)

    expect(described_class.call(user_id:)).to eq([ newer.goods, older.goods ])
  end

  it 'tells when each was added' do
    favorite = create(:favorite_goods, user_id:)

    expect(described_class.call(user_id:).sole.added_at).to eq(favorite.created_at)
  end

  it 'keeps a SKU withdrawn later and tells once it is shown again', :aggregate_failures do
    goods = create(:favorite_goods, user_id:).goods

    goods.goods_group.update!(withdrawn: true)
    expect(described_class.call(user_id:).sole.shown?).to be(false)

    goods.goods_group.update!(withdrawn: false)
    expect(described_class.call(user_id:).sole.shown?).to be(true)
  end

  it 'is empty for a user who added nothing' do
    expect(described_class.call(user_id:)).to eq([])
  end
end
