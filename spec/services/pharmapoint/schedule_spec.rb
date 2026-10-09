# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharmapoint::Schedule do
  def jobs(env = {}) = described_class.jobs(env)

  it 'schedules the dictionaries, the categories, the drugstores and the log cleanup by default' do
    expect(jobs.keys).to contain_exactly('catalog_sync_dictionaries', 'catalog_sync_categories',
                                         'catalog_sync_drugstores', 'provider_request_log_cleanup')
  end

  it 'keeps the goods groups off until the cron variable is set', :aggregate_failures do
    expect(jobs).not_to have_key('catalog_sync_goods_groups')
    expect(jobs('SYNC_CRON_GOODS_GROUPS' => '0 2 * * *')['catalog_sync_goods_groups'])
      .to include('cron' => '0 2 * * *', 'class' => 'Catalog::Sync::StartWorker', 'args' => [ 'goods_groups' ])
  end

  it 'takes the periodicity of a kind from the environment' do
    expect(jobs('SYNC_CRON_DRUGSTORES' => '15 5 * * *')['catalog_sync_drugstores']).to include('cron' => '15 5 * * *')
  end

  it 'turns off a job whose cron is empty' do
    expect(jobs('SYNC_CRON_CATEGORIES' => ' ')).not_to have_key('catalog_sync_categories')
  end

  it 'schedules nothing when every cron is empty' do
    env = { 'SYNC_CRON_DICTIONARIES' => '', 'SYNC_CRON_CATEGORIES' => '', 'SYNC_CRON_DRUGSTORES' => '',
            'LOG_CLEANUP_CRON' => '' }

    expect(jobs(env)).to eq({})
  end

  describe '.sync_enabled?' do
    it 'answers yes for a kind scheduled by default and no for the goods groups kept off', :aggregate_failures do
      expect(described_class.sync_enabled?('drugstores', {})).to be(true)
      expect(described_class.sync_enabled?('goods_groups', {})).to be(false)
    end

    it 'follows the cron set in the environment', :aggregate_failures do
      expect(described_class.sync_enabled?('goods_groups', 'SYNC_CRON_GOODS_GROUPS' => '0 2 * * *')).to be(true)
      expect(described_class.sync_enabled?('categories', 'SYNC_CRON_CATEGORIES' => ' ')).to be(false)
    end

    it 'answers no for a kind the schedule does not know' do
      expect(described_class.sync_enabled?('symptoms', {})).to be(false)
    end
  end

  it 'names a worker that exists for every entry' do
    expect(jobs.values.pluck('class').map(&:constantize)).to all(include(Sidekiq::Job))
  end
end
