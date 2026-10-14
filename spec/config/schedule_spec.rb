# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'the schedule of recurring jobs' do # rubocop:disable RSpec/DescribeClass
  let(:cron_variables) do
    Catalog::Sync::Cron::KINDS.values.map(&:first) + %w[LOG_CLEANUP_CRON SEO_SITEMAP_CRON SEO_REDIRECT_CLEANUP_CRON]
  end

  # Renders the file as sidekiq-cron does, with the cron variables unset unless given, so their defaults apply.
  def jobs(env = {})
    stub_const('ENV', ENV.to_h.except(*cron_variables).merge(env))
    Sidekiq::Cron::Support.load_yaml(ERB.new(Rails.root.join('config/schedule.yml').read).result) || {}
  end

  it 'schedules the dictionaries, the categories, the drugstores, the log cleanup and the SEO jobs by default' do
    expect(jobs.keys).to contain_exactly('catalog_sync_dictionaries', 'catalog_sync_categories',
                                         'catalog_sync_drugstores', 'provider_request_log_cleanup',
                                         'seo_sitemap', 'seo_redirect_cleanup')
  end

  it 'runs the sitemap and the redirect cleanup every day by default' do
    expect(jobs).to include('seo_sitemap' => include('cron' => '0 5 * * *', 'class' => 'Seo::SitemapWorker'),
                            'seo_redirect_cleanup' => include('cron' => '40 4 * * *'))
  end

  it 'takes the periodicity of the SEO jobs from the environment' do
    expect(jobs('SEO_SITEMAP_CRON' => '30 6 * * *')['seo_sitemap']).to include('cron' => '30 6 * * *')
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
