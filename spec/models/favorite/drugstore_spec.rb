# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorite::Drugstore do
  it 'keeps a drugstore once per user' do
    favorite = create(:favorite_drugstore)

    duplicate = -> { create(:favorite_drugstore, user_id: favorite.user_id, drugstore: favorite.drugstore) }

    expect(&duplicate).to raise_error(ActiveRecord::RecordNotUnique)
  end

  it 'needs a user the core has' do
    expect(build(:favorite_drugstore, user_id: 0)).not_to be_valid
  end

  it 'goes with the drugstore when the drugstore is deleted' do
    favorite = create(:favorite_drugstore)

    favorite.drugstore.delete

    expect(described_class.exists?(favorite.id)).to be(false)
  end

  it 'belongs to a core user, reached from both sides without a foreign key', :aggregate_failures do
    user = create(:h24_core_user)
    favorite = create(:favorite_drugstore, user_id: user.id)

    expect(favorite.user).to eq(user)
    expect(user.favorite_drugstores).to eq([ favorite ])
  end
end
