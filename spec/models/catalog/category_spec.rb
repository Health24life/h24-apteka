# spec/models/catalog/category_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Category do
  it_behaves_like 'a translatable catalog record', :catalog_category

  it 'is valid with a Ukrainian name' do
    expect(build(:catalog_category)).to be_valid
  end

  describe 'slug' do
    it 'is generated from the Ukrainian name on creation' do
      expect(create(:catalog_category, name_uk: 'Знеболювальні').slug).to eq('zneboliuvalni')
    end

    it 'gets a numeric suffix when the address is taken' do
      create(:catalog_category, name_uk: 'Знеболювальні')

      expect(create(:catalog_category, name_uk: 'Знеболювальні').slug).to eq('zneboliuvalni-2')
    end

    it 'does not change when the category is renamed' do
      category = create(:catalog_category, name_uk: 'Знеболювальні')

      category.update!(name_uk: 'Анальгетики')

      expect(category.reload.slug).to eq('zneboliuvalni')
    end

    it 'refuses a manual change' do
      category = create(:catalog_category)

      expect { category.update(slug: 'other') }.to raise_error(ActiveRecord::ReadonlyAttributeError)
    end

    it 'refuses a slug changed by writing the attribute directly' do
      category = create(:catalog_category)
      category[:slug] = 'other'

      expect(category).not_to be_valid
    end

    it 'falls back to a fixed word for a name without letters' do
      expect(create(:catalog_category, name_uk: '!!!').slug).to eq('item')
    end

    it 'refuses a malformed slug in validation' do
      expect(build(:catalog_category).tap { |c| c.slug = 'Bad Slug' }).not_to be_valid
    end

    it 'refuses a duplicate slug at the database level' do
      category = create(:catalog_category)
      other = create(:catalog_category)

      expect { other.update_column(:slug, category.slug) }.to raise_error(ActiveRecord::RecordNotUnique) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'refuses a malformed slug at the database level' do
      category = create(:catalog_category)

      expect { category.update_column(:slug, 'Bad_Slug') } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /catalog_categories_slug_check/)
    end

    it 'refuses a slug longer than the limit at the database level' do
      category = create(:catalog_category)

      expect { category.update_column(:slug, 'a' * 101) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::StatementInvalid, /catalog_categories_slug_check/)
    end

    it 'creates a category whose name contains an underscore' do
      expect(create(:catalog_category, name_uk: 'Вітамін_С').slug).to eq('vitamin-s')
    end
  end

  describe 'tree' do
    it 'treats a node without a parent as a root', :aggregate_failures do
      root = create(:catalog_category)
      child = create(:catalog_category, parent: root, depth: 1)

      expect(described_class.roots).to contain_exactly(root)
      expect(root.children).to contain_exactly(child)
    end

    it 'refuses a category as its own parent' do
      category = create(:catalog_category)

      category.parent = category

      expect(category).not_to be_valid
    end

    it 'refuses a category as its own parent at the database level' do
      category = create(:catalog_category)

      expect { category.update_column(:parent_id, category.id) }.to raise_error(ActiveRecord::StatementInvalid) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'refuses to delete a category that has children' do
      root = create(:catalog_category)
      create(:catalog_category, parent: root)

      expect { root.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end

    it 'refuses a negative depth', :aggregate_failures do
      expect(build(:catalog_category, depth: -1)).not_to be_valid
      category = create(:catalog_category)
      expect { category.update_column(:depth, -1) }.to raise_error(ActiveRecord::StatementInvalid) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  it 'refuses to delete a category that has a provider link' do
    link = create(:provider_link, linkable: create(:catalog_category))

    expect { link.linkable.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

# == Schema Information
#
# Table name: catalog_categories
#
#  id         :bigint           not null, primary key
#  depth      :integer          default(0), not null
#  name       :string
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#
# Indexes
#
#  index_catalog_categories_on_parent_id  (parent_id)
#  index_catalog_categories_on_slug       (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => catalog_categories.id)
#
# Check Constraints
#
#  catalog_categories_depth_check   (depth >= 0)
#  catalog_categories_parent_check  (parent_id IS NULL OR parent_id <> id)
#  catalog_categories_slug_check    (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#
