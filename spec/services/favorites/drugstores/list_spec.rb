# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Favorites::Drugstores::List do
  let(:user_id) { 42 }

  it 'lists the drugstores of the user, the last added first' do
    older = create(:favorite_drugstore, user_id:, created_at: 2.days.ago)
    newer = create(:favorite_drugstore, user_id:, created_at: 1.day.ago)
    create(:favorite_drugstore, user_id: 7)

    expect(described_class.call(user_id:)).to eq([ newer.drugstore, older.drugstore ])
  end

  it 'keeps a drugstore withdrawn later and tells once it is back', :aggregate_failures do
    drugstore = create(:favorite_drugstore, user_id:).drugstore

    drugstore.update!(withdrawn: true)
    expect(described_class.call(user_id:).sole.shown?).to be(false)

    drugstore.update!(withdrawn: false)
    expect(described_class.call(user_id:).sole.shown?).to be(true)
  end
end
