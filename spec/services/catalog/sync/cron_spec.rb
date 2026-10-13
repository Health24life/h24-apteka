# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Cron do
  it 'gives the default cron of a kind and none for the goods groups kept off', :aggregate_failures do
    expect(described_class.of('drugstores', {})).to eq('30 3 * * *')
    expect(described_class.of('goods_groups', {})).to be_nil
  end

  it 'follows the cron set in the environment', :aggregate_failures do
    expect(described_class.enabled?('goods_groups', 'SYNC_CRON_GOODS_GROUPS' => '0 2 * * *')).to be(true)
    expect(described_class.enabled?('categories', 'SYNC_CRON_CATEGORIES' => ' ')).to be(false)
  end

  it 'answers no for a kind it does not know' do
    expect(described_class.enabled?('symptoms', {})).to be(false)
  end
end
