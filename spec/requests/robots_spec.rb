# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search engines on the API host' do
  it 'closes the whole host to crawling' do
    expect(Rails.public_path.join('robots.txt').read).to match(%r{^User-agent: \*\nDisallow: /$})
  end

  it 'marks an answer of the API as not for the index' do
    get '/api/v1/seo/page', params: { path: '/tovar/nema-takoho' }

    expect(response.headers['X-Robots-Tag']).to eq('noindex, follow')
  end

  it 'marks the other answers of the host too' do
    get '/admin/login'

    expect(response.headers['X-Robots-Tag']).to eq('noindex, follow')
  end
end
