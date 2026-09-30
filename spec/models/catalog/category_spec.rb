# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::Category do
  it_behaves_like 'a translatable catalog record', :catalog_category
  it_behaves_like 'a sluggable catalog record', :catalog_category

  it 'is valid with a Ukrainian name' do
    expect(build(:catalog_category)).to be_valid
  end

  describe 'tree' do
    it 'treats a node without a parent as a root', :aggregate_failures do
      root = create(:catalog_category)
      child = create(:catalog_category, parent: root)

      expect(described_class.roots).to contain_exactly(root)
      expect(root.children).to contain_exactly(child)
    end

    it 'refuses a category as its own parent' do
      category = create(:catalog_category)

      category.parent = category

      expect(category).not_to be_valid
    end

    it 'refuses a descendant as the parent, which would close a cycle', :aggregate_failures do
      root = create(:catalog_category)
      grandchild = create(:catalog_category, parent: create(:catalog_category, parent: root))

      root.parent = grandchild

      expect(root).not_to be_valid
      expect(root.errors[:parent]).to be_present
    end

    it 'allows moving a category under an unrelated branch' do
      category = create(:catalog_category, parent: create(:catalog_category))

      expect(category.update(parent: create(:catalog_category))).to be(true)
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

    it 'derives the depth from the parent, ignoring a given value', :aggregate_failures do
      root = create(:catalog_category, depth: 5)
      child = create(:catalog_category, parent: root, depth: 0)

      expect(root.depth).to eq(0)
      expect(child.depth).to eq(1)
    end

    it 'shifts the depth of the whole branch when a category moves', :aggregate_failures do
      child = create(:catalog_category, parent: create(:catalog_category))
      grandchild = create(:catalog_category, parent: child)

      child.update!(parent: create(:catalog_category, parent: create(:catalog_category)))

      expect(child.reload.depth).to eq(2)
      expect(grandchild.reload.depth).to eq(3)
    end

    it 'refuses a negative depth at the database level' do
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
