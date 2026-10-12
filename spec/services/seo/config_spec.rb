# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Config do
  def config(env = {}) = described_class.from_env(env)

  it 'falls back to the defaults when the environment says nothing', :aggregate_failures do
    expect(config).to have_attributes(front_base_url: nil, filter_params: [], sitemap_dir: nil,
                                      forbidden_words: described_class::FORBIDDEN_WORDS, redirect_ttl: 3.months)
  end

  it 'reads every setting from the environment', :aggregate_failures do
    env = { 'APTEKA_FRONT_BASE_URL' => 'https://apteka.h24.ua/', 'SEO_FILTER_PARAMS' => ' Form, brand ,,',
            'SEO_FORBIDDEN_WORDS' => 'Дешево', 'SEO_REDIRECT_TTL_MONTHS' => '6', 'SEO_SITEMAP_DIR' => '/data/sitemaps' }

    expect(config(env)).to have_attributes(front_base_url: 'https://apteka.h24.ua', filter_params: %w[form brand],
                                           forbidden_words: [ 'дешево' ], redirect_ttl: 6.months,
                                           sitemap_dir: '/data/sitemaps')
  end

  it 'refuses to build front URLs without the front base URL' do
    expect { config.front_base_url! }.to raise_error(described_class::MissingSetting, /APTEKA_FRONT_BASE_URL/)
  end

  it 'refuses to write a sitemap without its directory' do
    expect { config.sitemap_dir! }.to raise_error(described_class::MissingSetting, /SEO_SITEMAP_DIR/)
  end

  it 'takes the section prefix from the path of the front base URL', :aggregate_failures do
    expect(config('APTEKA_FRONT_BASE_URL' => 'https://apteka.h24.ua').front_path_prefix).to eq('')
    expect(config('APTEKA_FRONT_BASE_URL' => 'https://h24.ua/apteka/').front_path_prefix).to eq('/apteka')
  end
end
