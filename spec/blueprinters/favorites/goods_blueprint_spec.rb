# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorites::GoodsBlueprint do
  def render_list = QueryLog.capture { described_class.render_as_hash(Favorites::Goods::List.call(user_id: 42)) }

  it 'reads a list in the same number of statements however long it is' do
    create(:favorite_goods, user_id: 42)
    short = render_list
    create_list(:favorite_goods, 3, user_id: 42)

    expect(render_list.size).to eq(short.size)
  end
end
