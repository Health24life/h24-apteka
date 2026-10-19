# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'the schedule of recurring jobs' do # rubocop:disable RSpec/DescribeClass
  let(:cron_variables) do
    Catalog::Sync::Cron::KINDS.values.map(&:first) + %w[
      LOG_CLEANUP_CRON
      SYNC_PULL_RUN_CLEANUP_CRON
      ORDERS_CART_CLEANUP_CRON
      APTEKA_BOOKING_STATUS_POLL_CRON
    ]
  end

  # Renders the file as sidekiq-cron does, with the cron variables unset unless given, so their defaults apply.
  def jobs(env = {})
    stub_const('ENV', ENV.to_h.except(*cron_variables).merge(env))
    Sidekiq::Cron::Support.load_yaml(ERB.new(Rails.root.join('config/schedule.yml').read).result) || {}
  end

  it 'schedules the dictionaries, the categories, the drugstores and the cleanups by default' do
    expect(jobs.keys).to contain_exactly(
      'catalog_sync_dictionaries',
      'catalog_sync_categories',
      'catalog_sync_drugstores',
      'provider_request_log_cleanup',
      'catalog_sync_pull_run_cleanup',
      'orders_cart_abandoned_cleanup',
      'orders_booking_status_poll'
    )
  end

  it 'polls the statuses of sent orders every ten minutes unless the environment says otherwise', :aggregate_failures do
    expect(jobs['orders_booking_status_poll'])
      .to include('cron' => '*/10 * * * *', 'class' => 'Orders::Bookings::StatusPollWorker')
    expect(jobs('APTEKA_BOOKING_STATUS_POLL_CRON' => '')).not_to have_key('orders_booking_status_poll')
  end

  it 'takes the periodicity of the cleanup of abandoned guest carts from the environment', :aggregate_failures do
    expect(jobs['orders_cart_abandoned_cleanup'])
      .to include('cron' => '40 4 * * *', 'class' => 'Orders::Carts::AbandonedCleanupWorker')
    expect(jobs('ORDERS_CART_CLEANUP_CRON' => '')).not_to have_key('orders_cart_abandoned_cleanup')
  end

  it 'takes the periodicity of the cleanup of on-demand fetches from the environment', :aggregate_failures do
    expect(jobs['catalog_sync_pull_run_cleanup'])
      .to include('cron' => '20 4 * * *', 'class' => 'Catalog::Sync::PullRunCleanupWorker')
    expect(jobs('SYNC_PULL_RUN_CLEANUP_CRON' => '0 5 * * *')['catalog_sync_pull_run_cleanup'])
      .to include('cron' => '0 5 * * *')
    expect(jobs('SYNC_PULL_RUN_CLEANUP_CRON' => '')).not_to have_key('catalog_sync_pull_run_cleanup')
  end

  it 'passes the kind of data to the worker that starts a run' do
    expect(jobs['catalog_sync_categories'])
      .to include('cron' => '10 3 * * *', 'class' => 'Catalog::Sync::StartWorker', 'args' => [ 'categories' ])
  end

  it 'keeps the goods groups off until the cron variable is set', :aggregate_failures do
    expect(jobs).not_to have_key('catalog_sync_goods_groups')
    expect(jobs('SYNC_CRON_GOODS_GROUPS' => '0 2 * * *')['catalog_sync_goods_groups'])
      .to include('cron' => '0 2 * * *', 'class' => 'Catalog::Sync::StartWorker', 'args' => [ 'goods_groups' ])
  end

  it 'takes the periodicity of a job from the environment', :aggregate_failures do
    expect(jobs('SYNC_CRON_DRUGSTORES' => '15 5 * * *')['catalog_sync_drugstores']).to include('cron' => '15 5 * * *')
    expect(jobs('LOG_CLEANUP_CRON' => '0 6 * * *')['provider_request_log_cleanup']).to include('cron' => '0 6 * * *')
  end

  it 'leaves out a job whose cron is empty', :aggregate_failures do
    expect(jobs('SYNC_CRON_CATEGORIES' => ' ')).not_to have_key('catalog_sync_categories')
    expect(jobs('LOG_CLEANUP_CRON' => '')).not_to have_key('provider_request_log_cleanup')
  end

  it 'names a worker that exists for every entry' do
    expect(jobs.values.pluck('class').map(&:constantize)).to all(include(Sidekiq::Job))
  end

  it 'gives every entry a cron sidekiq-cron accepts' do
    expect(jobs.map { |name, job| Sidekiq::Cron::Job.new(job.merge('name' => name)) }).to all(be_valid)
  end
end
