# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Sync::Pulls::Stash do
  include ActiveSupport::Testing::TimeHelpers

  let(:provider) { create(:provider, code: 'pharmapoint') }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:records) { JSON.parse(pharmapoint_fixture('goods_group_search'))['data'] }
  let(:complete) { records.first.tap { it['release_forms'].each { it['instruction'] ||= '<p>Склад</p>' } } }
  let(:group_id) { 'a060d7776d3d256af22378e018bea336' }

  before { allow(Rails).to receive(:cache).and_return(cache) }

  def write(records = [ complete ], **) = described_class.write(provider:, records:, config: sync_config(**))

  it 'keeps a group under a key of the provider and the group, and reads it back without the live fields',
     :aggregate_failures do
    keys = write

    expect(keys).to eq(group_id => "catalog_sync_stash:#{provider.id}:goods_group:#{group_id}")
    stashed = described_class.read(keys.fetch(group_id))
    expect(stashed).to include('id' => group_id)
    expect(stashed).not_to have_key('online_price')
  end

  it 'does not keep a group that lacks what a save needs' do
    expect(write([ complete, records.last ]).keys).to eq([ group_id ])
  end

  it 'lets an entry expire', :aggregate_failures do
    keys = write(pull: { stash_ttl: 60 })

    travel_to(2.minutes.from_now) { expect(described_class.read(keys.fetch(group_id))).to be_nil }
  end

  it 'reads nothing for a key it never wrote' do
    expect(described_class.read(described_class.key(provider.id, 'none'))).to be_nil
  end

  it 'reports a failed write instead of raising', :aggregate_failures do
    allow(cache).to receive(:write_multi).and_raise(Redis::CannotConnectError)
    allow(Rails.error).to receive(:report)

    expect(write).to eq({})
    expect(Rails.error).to have_received(:report)
  end
end
