# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Schedule do
  def jobs(env = {}) = described_class.jobs(env)

  it 'schedules the sitemap and the redirect cleanup by default' do
    expect(jobs.keys).to contain_exactly('seo_sitemap', 'seo_redirect_cleanup')
  end

  it 'takes the periodicity from the environment' do
    expect(jobs('SEO_SITEMAP_CRON' => '15 6 * * *')['seo_sitemap'])
      .to include('cron' => '15 6 * * *', 'class' => 'Seo::SitemapWorker')
  end

  it 'turns off a job whose cron is empty' do
    expect(jobs('SEO_REDIRECT_CLEANUP_CRON' => ' ')).not_to have_key('seo_redirect_cleanup')
  end

  it 'names a worker that exists for every entry' do
    expect(jobs.values.pluck('class').map(&:constantize)).to all(include(Sidekiq::Job))
  end
end
