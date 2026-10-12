# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Redirects::Cleanup do
  it 'removes the redirects older than the period and keeps the rest', :aggregate_failures do
    fresh = create(:seo_redirect, created_at: 1.month.ago)
    create(:seo_redirect, created_at: 4.months.ago)

    expect(described_class.call).to eq(1)
    expect(Seo::Redirect.all).to contain_exactly(fresh)
  end

  it 'frees the old slug for another record' do
    goods = create(:catalog_goods, name_uk: 'Нурофен')
    goods.update!(slug: 'nurofen-forte')
    goods.seo_redirects.update_all(created_at: 4.months.ago) # rubocop:disable Rails/SkipsModelValidations

    described_class.call

    expect(create(:catalog_goods, name_uk: 'Нурофен').slug).to eq('nurofen')
  end

  it 'follows the period from the environment' do
    create(:seo_redirect, created_at: 2.months.ago)
    allow(Seo::Config).to receive(:current).and_return(Seo::Config.new(redirect_ttl: 1.month))

    expect(described_class.call).to eq(1)
  end
end
