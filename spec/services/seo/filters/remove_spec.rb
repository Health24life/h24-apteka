# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Filters::Remove do
  let(:config) { Seo::Config.new(front_base_url: 'https://apteka.h24.ua') }
  let(:filter) { create(:seo_filter, :published, slug: 'vitaminy-dlia-ditei') }

  def remove(target = nil) = described_class.call(filter:, target:, config:)

  def status = Seo::Pages::Resolve.call('/dobirka/vitaminy-dlia-ditei', config:)

  it 'leaves the address answering 410 without a target', :aggregate_failures do
    expect(remove).to be_ok
    expect(filter.reload).to be_removed
    expect(status.status).to eq(410)
  end

  it 'takes a blank target for none' do
    remove('  ')

    expect(status.status).to eq(410)
  end

  it 'leads the address to the page the editor chose', :aggregate_failures do
    category = create(:catalog_category, slug: 'vitaminy')

    result = remove('https://apteka.h24.ua/katalog/vitaminy')

    expect(result.redirect).to have_attributes(manual: true, page_type: 'filter', redirectable: category)
    expect(status.location).to eq('/katalog/vitaminy')
  end

  context 'with a target of another kind' do
    let(:goods) { create(:catalog_goods) }
    let(:page) { create(:seo_static_page, :published) }
    let(:other) { create(:seo_filter, :published) }

    def target_of(path)
      described_class.call(filter: create(:seo_filter, :published), target: path, config:).redirect&.redirectable
    end

    it 'leads to a SKU, a static page or another filter', :aggregate_failures do
      expect(target_of("/tovar/#{goods.slug}")).to eq(goods)
      expect(target_of("/#{page.slug}")).to eq(page)
      expect(target_of("/dobirka/#{other.slug}")).to eq(other)
    end
  end

  it 'leaves the filter as it was when the target is refused', :aggregate_failures do
    hidden = create(:catalog_goods, hidden: true)

    expect(remove("/tovar/#{hidden.slug}").errors).to eq(target: :unavailable)
    expect(remove('https://h24.ua/doctors').errors).to eq(target: :other_host)
    expect(filter.reload).to have_attributes(published: true, removed_at: nil)
    expect(Seo::Redirect.count).to eq(0)
  end

  it 'undoes the removal when the redirect cannot be kept', :aggregate_failures do
    create(:catalog_category, slug: 'vitaminy')
    allow(Seo::Redirects::Manual).to receive(:call)
      .and_return(Seo::Redirects::Manual::Result.new(redirect: nil, errors: { source: :redirected }))

    expect(remove('/katalog/vitaminy').errors).to eq(source: :redirected)
    expect(filter.reload).not_to be_removed
  end
end
