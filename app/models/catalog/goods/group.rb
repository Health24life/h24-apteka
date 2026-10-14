# frozen_string_literal: true

class Catalog::Goods::Group < ApplicationRecord
  include Catalog::ProviderLinked
  include Translatable

  translatable :name, backend: :table

  belongs_to :producer, class_name: 'Catalog::Producer', optional: true, inverse_of: :goods_groups
  belongs_to :goods_name, class_name: 'Catalog::Goods::Name', optional: true, inverse_of: :goods_groups
  belongs_to :atc_class, class_name: 'Catalog::AtcClass', optional: true, inverse_of: :goods_groups

  has_many :goods, class_name: 'Catalog::Goods', inverse_of: :goods_group, dependent: :restrict_with_exception
  has_many :goods_group_categories, class_name: 'Catalog::Goods::Group::Category', inverse_of: :goods_group,
                                    dependent: :delete_all
  has_many :categories, through: :goods_group_categories
  has_one :primary_goods_group_category, -> { where(is_primary: true) }, class_name: 'Catalog::Goods::Group::Category',
                                                                         inverse_of: :goods_group,
                                                                         dependent: nil
  has_one :primary_category, through: :primary_goods_group_category, source: :category

  validates :name_uk, presence: true

  # The name lives in the translations table, so the admin filters by it through this scope rather than a column.
  scope :name_cont, lambda { |text|
    joins(:translations).where('catalog_goods_group_translations.name ILIKE ?', "%#{sanitize_sql_like(text.to_s)}%")
  }

  # Groups the provider put anywhere in the branch of a category, whether it is their primary one or not.
  scope :in_branch, lambda { |category_id|
    where(<<~SQL.squish, category_id)
      catalog_goods_groups.id IN (
        SELECT link.goods_group_id FROM catalog_goods_group_categories link
        JOIN catalog_category_hierarchies hierarchy ON hierarchy.descendant_id = link.category_id
        WHERE hierarchy.ancestor_id = ?
      )
    SQL
  }

  def self.ransackable_scopes(_auth_object = nil) = %i[name_cont in_branch]
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
