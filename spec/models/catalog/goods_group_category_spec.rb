# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::GoodsGroupCategory do
  let(:group) { create(:catalog_goods_group) }

  it 'refuses the same category twice for one group' do
    link = create(:catalog_goods_group_category, goods_group: group)

    duplicate = build(:catalog_goods_group_category, goods_group: group, category: link.category)

    expect(duplicate).not_to be_valid
  end

  it 'refuses a second main category for one group' do
    create(:catalog_goods_group_category, goods_group: group, is_primary: true)

    second = build(:catalog_goods_group_category, goods_group: group, is_primary: true)

    expect(second).not_to be_valid
  end

  it 'allows many non-main categories and main categories in other groups', :aggregate_failures do
    create(:catalog_goods_group_category, goods_group: group)
    expect(build(:catalog_goods_group_category, goods_group: group)).to be_valid

    create(:catalog_goods_group_category, goods_group: group, is_primary: true)
    expect(build(:catalog_goods_group_category, is_primary: true)).to be_valid
  end

  describe 'bulk writes' do
    let(:first) { create(:catalog_goods_group_category, goods_group: group, is_primary: true) }
    let(:now) { Time.current }
    let(:row) { { goods_group_id: group.id, is_primary: false, created_at: now, updated_at: now } }

    it 'refuses the same category twice in the database' do
      expect { described_class.insert_all!([ row.merge(category_id: first.category_id) ]) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'refuses a second main category in the database' do
      other_category = create(:catalog_category)
      first

      expect { described_class.insert_all!([ row.merge(category_id: other_category.id, is_primary: true) ]) } # rubocop:disable Rails/SkipsModelValidations
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  it 'refuses to delete a category that has groups' do
    link = create(:catalog_goods_group_category)

    expect { link.category.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end

  it 'refuses to delete an ATC class that has groups' do
    atc = create(:catalog_atc_class)
    create(:catalog_goods_group, atc_class: atc)

    expect { atc.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

# == Schema Information
#
# Table name: catalog_goods_group_categories
#
#  id             :bigint           not null, primary key
#  is_primary     :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  category_id    :bigint           not null
#  goods_group_id :bigint           not null
#
# Indexes
#
#  index_catalog_goods_group_categories_on_category_id  (category_id)
#  index_catalog_goods_group_categories_primary         (goods_group_id) UNIQUE WHERE is_primary
#  index_catalog_goods_group_categories_uniqueness      (goods_group_id,category_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => catalog_categories.id)
#  fk_rails_...  (goods_group_id => catalog_goods_groups.id) ON DELETE => cascade
#
