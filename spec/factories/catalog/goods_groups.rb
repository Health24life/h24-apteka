# frozen_string_literal: true

FactoryBot.define do
  factory :catalog_goods_group, class: 'Catalog::GoodsGroup' do
    sequence(:name_uk) { |n| "Група товарів #{n}" }
  end
end

# == Schema Information
#
# Table name: catalog_goods_groups
#
#  id                 :bigint           not null, primary key
#  hidden             :boolean          default(FALSE), not null
#  included_to_offers :boolean          default(FALSE), not null
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
