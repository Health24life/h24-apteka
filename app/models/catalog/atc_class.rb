# frozen_string_literal: true

class Catalog::AtcClass < ApplicationRecord
  include Catalog::ProviderLinked
  include Translatable

  translatable :name

  # Save callbacks keep the hierarchy table, so a write past them (insert_all, upsert_all, update_all on parent_id)
  # has to be followed by rebuild!.
  has_closure_tree dependent: :restrict_with_exception

  has_many :goods_groups, class_name: 'Catalog::Goods::Group', inverse_of: :atc_class,
                          dependent: :restrict_with_exception

  validates :atc_code, presence: true, uniqueness: true
end

# == Schema Information
#
# Table name: catalog_atc_classes
#
#  id         :bigint           not null, primary key
#  atc_code   :string           not null
#  name       :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#
# Indexes
#
#  index_catalog_atc_classes_on_atc_code   (atc_code) UNIQUE
#  index_catalog_atc_classes_on_parent_id  (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => catalog_atc_classes.id)
#
# Check Constraints
#
#  catalog_atc_classes_parent_check  (parent_id IS NULL OR parent_id <> id)
#
