# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorites::GoodsBlueprint do
  let(:user_id) { create(:h24_core_user).id }

  def render_list = QueryLog.capture { described_class.render_as_hash(Favorites::Goods::List.call(user_id:)) }

  it 'reads a list in the same number of statements however long it is' do
    create(:favorite_goods, user_id:)
    short = render_list
    create_list(:favorite_goods, 3, user_id:)

    expect(render_list.size).to eq(short.size)
  end
end
