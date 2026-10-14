# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Version do
  let(:admin) { create(:admin_user) }
  let(:category) { create(:catalog_category, slug: 'zneboliuvalni') }

  def as_admin(&) = PaperTrail.request(controller_info: { author: admin }, &)

  def changes_of(version) = version.object_changes

  it 'lays a change of an override on the card of its page with the admin who made it', :aggregate_failures do
    override = create(:seo_override, target: category, title_uk: 'Знеболювальні')

    as_admin { override.update!(title_uk: 'Знеболювальні засоби') }

    version = category.page_versions.newest_first.first
    expect(version).to have_attributes(event: 'update', author: admin, item: override)
    expect(changes_of(version)['title']).to eq([ { 'uk' => 'Знеболювальні' }, { 'uk' => 'Знеболювальні засоби' } ])
  end

  it 'lays a change of the SEO text on the card of the page as well', :aggregate_failures do
    override = create(:seo_override, target: category, seo_text_uk: '<p>Було</p>')

    as_admin { override.update!(seo_text_uk: '<p>Стало</p>') }

    version = category.page_versions.find_by(item_type: 'Seo::Override::Translation', event: 'update')
    expect(version.author).to eq(admin)
    expect(changes_of(version)['seo_text']).to eq([ '<p>Було</p>', '<p>Стало</p>' ])
  end

  it 'shows a slug change together with the redirect it left', :aggregate_failures do
    goods = create(:catalog_goods, slug: 'nurofen')

    as_admin { goods.update!(slug: 'nurofen-forte') }

    expect(goods.page_versions.map(&:item_type)).to contain_exactly('Catalog::Goods', 'Seo::Redirect')
    slug_change = goods.page_versions.find_by(item_type: 'Catalog::Goods')
    expect(changes_of(slug_change)['slug']).to eq(%w[nurofen nurofen-forte])
  end

  it 'keeps the history of a redirect after it is removed', :aggregate_failures do
    redirect = create(:seo_redirect, manual: true, page_type: 'goods', slug: 'stare', redirectable: category)

    as_admin { redirect.destroy! }

    expect(described_class.where(item: redirect).pluck(:event)).to contain_exactly('create', 'destroy')
    expect(described_class.find_by(item: redirect, event: 'destroy').author).to eq(admin)
  end

  it 'names no author for a change outside the admin' do
    create(:seo_template, title: '{name}').update!(title: '{name} — інструкція')

    expect(described_class.where(event: 'update').sole.author).to be_nil
  end

  it 'lays a change of a static page and its text on the page', :aggregate_failures do
    page = create(:seo_static_page, content_uk: '<p>Було</p>')

    as_admin { page.update!(published: true, content_uk: '<p>Стало</p>') }

    expect(page.page_versions.where(event: 'update').map(&:item_type))
      .to contain_exactly('Seo::StaticPage', 'Seo::StaticPage::Translation')
  end

  it 'leaves the creation and the renaming of catalog records out of the history', :aggregate_failures do
    goods = create(:catalog_goods)
    goods.update!(name_uk: 'Інша назва')
    create(:catalog_category).update!(name_uk: 'Інша категорія')

    expect(described_class.where(item_type: %w[Catalog::Goods Catalog::Category])).to be_empty
  end

  it 'leaves the cleanup of expired redirects out of the history' do
    create(:seo_redirect, created_at: 4.months.ago)

    expect { Seo::Redirects::Cleanup.call }.not_to change(described_class, :count)
  end
end
