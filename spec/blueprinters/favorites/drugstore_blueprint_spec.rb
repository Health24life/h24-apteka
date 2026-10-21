# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorites::DrugstoreBlueprint do
  let(:user_id) { create(:h24_core_user).id }

  def render_list = QueryLog.capture { described_class.render_as_hash(Favorites::Drugstores::List.call(user_id:)) }

  def favorite
    create(:favorite_drugstore, user_id:).tap { create(:catalog_drugstore_address, drugstore: it.drugstore) }
  end

  it 'reads a list in the same number of statements however long it is' do
    favorite
    short = render_list
    3.times { favorite }

    expect(render_list.size).to eq(short.size)
  end
end
