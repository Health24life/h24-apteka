# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog::GoodsGroup do
  it_behaves_like 'a translatable catalog record', :catalog_goods_group

  it 'has neither an address nor a slug' do
    expect(described_class.column_names).not_to include('slug')
  end

  it 'starts with all flags off' do
    expect(create(:catalog_goods_group)).to have_attributes(withdrawn: false, hidden: false, included_to_offers: false)
  end

  it 'keeps the hiding flags independent of each other', :aggregate_failures do
    group = create(:catalog_goods_group)

    group.update!(hidden: true)
    expect(group.reload).to have_attributes(withdrawn: false, hidden: true)

    group.update!(hidden: false, withdrawn: true)
    expect(group.reload).to have_attributes(withdrawn: true, hidden: false)
  end

  it 'takes producer, trade name and ATC class as optional', :aggregate_failures do
    expect(build(:catalog_goods_group)).to be_valid
    group = build(:catalog_goods_group, producer: create(:catalog_producer), goods_name: create(:catalog_goods_name),
                                        atc_class: create(:catalog_atc_class))
    expect(group).to be_valid
  end

  describe 'categories' do
    let(:group) { create(:catalog_goods_group) }
    let(:main) { create(:catalog_category) }

    before do
      create(:catalog_goods_group_category, goods_group: group, category: main, is_primary: true)
      create(:catalog_goods_group_category, goods_group: group)
    end

    it('exposes its main category') { expect(group.primary_category).to eq(main) }
    it('lists all its categories') { expect(group.categories.count).to eq(2) }
  end

  it 'removes its category links together with itself' do
    group = create(:catalog_goods_group)
    create(:catalog_goods_group_category, goods_group: group)

    expect { group.destroy }.to change(Catalog::GoodsGroupCategory, :count).by(-1)
  end

  it 'refuses to delete a group that has a provider link' do
    link = create(:provider_link, linkable: create(:catalog_goods_group))

    expect { link.linkable.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end

# == Schema Information
#
# Table name: catalog_goods_groups
#
#  id                 :bigint           not null, primary key
#  hidden             :boolean          default(FALSE), not null
#  included_to_offers :boolean          default(FALSE), not null
#  name               :string
#  withdrawn          :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  atc_class_id       :bigint
#  goods_name_id      :bigint
#  producer_id        :bigint
#
# Indexes
#
#  index_catalog_goods_groups_on_atc_class_id   (atc_class_id)
#  index_catalog_goods_groups_on_goods_name_id  (goods_name_id)
#  index_catalog_goods_groups_on_producer_id    (producer_id)
#
# Foreign Keys
#
#  fk_rails_...  (atc_class_id => catalog_atc_classes.id)
#  fk_rails_...  (goods_name_id => catalog_goods_names.id)
#  fk_rails_...  (producer_id => catalog_producers.id)
#
