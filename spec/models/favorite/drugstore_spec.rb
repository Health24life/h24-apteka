# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorite::Drugstore do
  it 'keeps a drugstore once per user' do
    favorite = create(:favorite_drugstore)

    duplicate = -> { create(:favorite_drugstore, user_id: favorite.user_id, drugstore: favorite.drugstore) }

    expect(&duplicate).to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'goes with the drugstore when the drugstore is deleted' do
    favorite = create(:favorite_drugstore)

    favorite.drugstore.delete

    expect(described_class.exists?(favorite.id)).to be(false)
  end
end
