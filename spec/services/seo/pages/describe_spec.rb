# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Pages::Describe do
  before { Seo::Templates::Defaults.call }

  it 'describes a page that is there', :aggregate_failures do
    create(:catalog_goods, name_uk: 'Нурофен 200 мг', slug: 'nurofen', dosage: '200 мг')
    described = described_class.call('/tovar/nurofen')

    expect(described).to have_attributes(status: 200, location: nil, robots: 'index, follow', seo_text: nil,
                                         title: 'Нурофен 200 мг — інструкція із застосування', h1: 'Нурофен 200 мг')
    expect(described.breadcrumbs.map(&:path)).to eq([ '/', '/tovar/nurofen' ])
  end

  it 'gives only the new path of a redirect' do
    create(:catalog_goods, slug: 'nurofen').update!(slug: 'nurofen-forte')

    expect(described_class.call('/tovar/nurofen')).to have_attributes(
      status: 301, location: '/tovar/nurofen-forte', title: nil, robots: nil, breadcrumbs: []
    )
  end

  it 'keeps a page that is not there out of search', :aggregate_failures do
    expect(described_class.call('/tovar/nema-takoho'))
      .to have_attributes(status: 404, title: nil, robots: 'noindex, nofollow', breadcrumbs: [])
    expect(described_class.call("/tovar/#{create(:catalog_goods, withdrawn: true).slug}"))
      .to have_attributes(status: 410, robots: 'noindex, nofollow')
  end

  it 'never asks the partner' do
    create(:catalog_goods, slug: 'nurofen')

    described_class.call('/tovar/nurofen')

    expect(a_request(:any, /pharmapoint/)).not_to have_been_made
  end

  it 'gives the text of a static page', :aggregate_failures do
    create(:seo_static_page, :published, name_uk: 'Умови сервісу', content_uk: '<p>Бронювання без передоплати.</p>')

    expect(described_class.call('/umovy-servisu'))
      .to have_attributes(status: 200, content: '<p>Бронювання без передоплати.</p>', h1: 'Умови сервісу')
  end

  it 'gives no text to the other pages', :aggregate_failures do
    create(:catalog_goods, slug: 'nurofen')
    create(:seo_static_page, :home)

    expect(described_class.call('/tovar/nurofen').content).to be_nil
    expect(described_class.call('/').content).to be_nil
  end
end
