# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::StaticPage do
  it_behaves_like 'a sluggable catalog record', :seo_static_page

  it 'is valid with a Ukrainian name' do
    expect(build(:seo_static_page)).to be_valid
  end

  it 'refuses a page without a name' do
    expect(build(:seo_static_page, name_uk: '')).not_to be_valid
  end

  it 'starts unpublished' do
    expect(create(:seo_static_page)).not_to be_published
  end

  it 'keeps the text in a translation', :aggregate_failures do
    page = create(:seo_static_page, content_uk: '<p>Умови</p>')

    expect(page.translations.sole).to have_attributes(locale: 'uk', content: '<p>Умови</p>')
  end

  it 'cleans the text of pictures and other tags before saving', :aggregate_failures do
    page = create(:seo_static_page, content_uk: '<p>Умови</p><img src="https://e.com/a.png"><iframe></iframe>')

    expect(page.reload.content_uk).to eq('<p>Умови</p>')
    expect(page).to be_html_sanitized
  end

  it 'refuses a slug that a route of the section takes', :aggregate_failures do
    page = build(:seo_static_page, slug: 'katalog')

    expect(page).not_to be_valid
    expect(page.errors.details[:slug]).to include(error: :reserved)
  end

  it 'refuses the slug of the route of the filters' do
    expect(build(:seo_static_page, slug: 'dobirka')).not_to be_valid
  end

  it 'gives a name that transliterates to a route of the section another slug' do
    expect(create(:seo_static_page, name_uk: 'Tovar').slug).to eq('tovar-2')
  end

  describe 'the home page' do
    subject(:home) { create(:seo_static_page, :home) }

    it 'has no slug of its own', :aggregate_failures do
      expect(home).to be_valid
      expect(home.slug).to be_nil
      expect(described_class.home).to eq(home)
    end

    it 'cannot be removed', :aggregate_failures do
      expect(home.destroy).to be(false)
      expect(home.errors.details[:base]).to include(error: :home_required)
      expect(described_class.exists?(home.id)).to be(true)
    end

    it 'is the only page with a key' do
      home

      expect(build(:seo_static_page, :home)).not_to be_valid
    end

    it 'refuses a slug at the database level' do
      expect { home.update_column(:slug, 'holovna') } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /seo_static_pages_slug_check/)
    end
  end

  it 'drops its override and the redirects to it with the page', :aggregate_failures do
    page = create(:seo_static_page, slug: 'umovy', seo_override: build(:seo_override, target: nil))
    page.update!(slug: 'umovy-servisu')

    page.destroy!

    expect(Seo::Override.count).to eq(0)
    expect(Seo::Redirect.count).to eq(0)
  end
end

# == Schema Information
#
# Table name: seo_static_pages
#
#  id         :bigint           not null, primary key
#  key        :string
#  name       :jsonb            not null
#  published  :boolean          default(FALSE), not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_seo_static_pages_on_key   (key) UNIQUE
#  index_seo_static_pages_on_slug  (slug) UNIQUE
#
# Check Constraints
#
#  seo_static_pages_slug_check  (key::text = 'home'::text AND slug IS NULL OR key IS NULL AND slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#
