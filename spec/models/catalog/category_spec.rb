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
      expect(root.errors[:parent_id]).to be_present
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

    context 'with a branch of three levels' do
      let(:root) { create(:catalog_category) }
      let(:child) { create(:catalog_category, parent: root) }
      let(:grandchild) { create(:catalog_category, parent: child) }

      it 'knows the ancestors, the descendants and the depth of a node', :aggregate_failures do
        expect(grandchild.ancestors).to eq([ child, root ])
        expect(root.self_and_descendants).to contain_exactly(root, child, grandchild)
        expect(grandchild.depth).to eq(2)
      end

      it 'carries the whole branch along when a category moves', :aggregate_failures do
        new_root = create(:catalog_category)
        grandchild

        child.update!(parent: new_root)

        expect(grandchild.reload.ancestors).to eq([ child, new_root ])
        expect(root.descendants).to be_empty
      end
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
#  name       :jsonb            not null
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
#  catalog_categories_parent_check  (parent_id IS NULL OR parent_id <> id)
#  catalog_categories_slug_check    (slug::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text AND length(slug::text) <= 100)
#
