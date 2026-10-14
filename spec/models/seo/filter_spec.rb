# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Seo::Filter do
  it_behaves_like 'a sluggable catalog record', :seo_filter

  it 'is valid with a Ukrainian name' do
    expect(build(:seo_filter)).to be_valid
  end

  it 'generates the address from the Ukrainian name' do
    expect(create(:seo_filter, name_uk: 'Вітаміни для дітей').slug).to eq('vitaminy-dlia-ditei')
  end

  it 'starts unpublished, sorted by name and without prescription goods' do
    expect(create(:seo_filter))
      .to have_attributes(published: false, sort_order: 'name', recipe_scope: 'otc', params: {}, position: 0)
  end

  it 'refuses a filter without a name', :aggregate_failures do
    filter = build(:seo_filter, name_uk: '')

    expect(filter).not_to be_valid
    expect(filter.errors).to include(:name_uk)
  end

  it 'refuses a name that calls to buy, as it becomes the heading of the page', :aggregate_failures do
    filter = build(:seo_filter, name_uk: 'Купити вітаміни для дітей')

    expect(filter).not_to be_valid
    expect(filter.errors.details[:name_uk]).to include(a_hash_including(error: :not_neutral))
  end

  it 'refuses an unknown order of goods or prescription scope', :aggregate_failures do
    expect(build(:seo_filter, sort_order: 'price')).not_to be_valid
    expect(build(:seo_filter, recipe_scope: 'all')).not_to be_valid
  end

  it 'refuses a negative position' do
    expect(build(:seo_filter, position: -1)).not_to be_valid
  end

  it 'refuses an unknown parameter and names it' do
    filter = build(:seo_filter, params: { 'price_max' => [ 100 ] })
    filter.validate

    expect(filter.errors.details[:params]).to include(error: :unknown_param, param: 'price_max')
  end

  it 'knows the parameters of the catalog search in the order of the page' do
    expect(described_class::PARAMS.keys).to eq(
      %w[category_id form_id producer_id adult_restriction_id child_restriction_id diabetic_restriction_id
         driver_restriction_id pregnant_and_lactating_restriction_id]
    )
  end

  it 'keeps an unpublished filter without parameters, but cannot publish it', :aggregate_failures do
    filter = create(:seo_filter)

    expect(filter.update(published: true)).to be(false)
    expect(filter.errors.details[:params]).to include(error: :blank)
  end

  it 'publishes a filter with parameters' do
    expect(create(:seo_filter, :published)).to be_published
  end

  it 'refuses a category that is not in the catalog' do
    expect { create(:seo_filter, category_id: 999_999) }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'keeps a category with filters from being removed' do
    category = create(:catalog_category)
    create(:seo_filter, category:)

    expect { category.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  describe '.listed' do
    it 'gives the published filters that are not removed' do
      published = create(:seo_filter, :published)
      create(:seo_filter)
      create(:seo_filter, :published).remove!

      expect(described_class.listed).to eq([ published ])
    end
  end

  describe '#remove!' do
    subject(:filter) { create(:seo_filter, :published, slug: 'dlia-skhudnennia') }

    it 'takes the filter off the section and keeps it', :aggregate_failures do
      filter.remove!

      expect(filter.reload).to be_removed
      expect(filter).not_to be_published
    end

    it 'keeps the address of a removed filter from another filter', :aggregate_failures do
      filter.remove!
      other = build(:seo_filter, slug: 'dlia-skhudnennia')

      expect(other).not_to be_valid
      expect(other.errors.details[:slug]).to include(a_hash_including(error: :taken))
    end

    it 'drops the redirects to the filter', :aggregate_failures do
      filter.update!(slug: 'stara')
      filter.update!(slug: 'nova')
      create(:seo_redirect, manual: true, page_type: 'goods', slug: 'staryi-tovar', redirectable: filter)

      expect { filter.remove! }.to change(Seo::Redirect, :count).from(3).to(0)
    end

    it 'cannot be published again' do
      filter.remove!

      expect(filter.update(published: true)).to be(false)
    end

    it 'refuses a published removed filter at the database level' do
      filter.remove!

      expect { filter.update_column(:published, true) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /seo_filters_removed_check/)
    end
  end

  it 'keeps a history of its changes for its page', :aggregate_failures do
    filter = create(:seo_filter, name_uk: 'Вітаміни')

    filter.update!(position: 2)

    expect(filter.page_versions.pluck(:event)).to contain_exactly('create', 'update')
  end
end

# == Schema Information
#
# Table name: seo_filters
#
#  id           :bigint           not null, primary key
#  name         :jsonb            not null
#  params       :jsonb            not null
#  position     :integer          default(0), not null
#  published    :boolean          default(FALSE), not null
#  recipe_scope :string           default("otc"), not null
#  removed_at   :datetime
#  slug         :string           not null
#  sort_order   :string           default("name"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  category_id  :bigint
#
# Indexes
#
#  index_seo_filters_listed   (category_id,position) WHERE (published AND (removed_at IS NULL))
#  index_seo_filters_on_slug  (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => catalog_categories.id)
#
# Check Constraints
#
#  seo_filters_position_check      ("position" >= 0)
#  seo_filters_recipe_scope_check  (recipe_scope::text = ANY (ARRAY['otc'::character varying, 'rx'::character varying, 'any'::character varying]::text[]))
#  seo_filters_removed_check       (removed_at IS NULL OR NOT published)
#  seo_filters_slug_check          (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#  seo_filters_sort_order_check    (sort_order::text = ANY (ARRAY['name'::character varying, 'newest'::character varying]::text[]))
#
