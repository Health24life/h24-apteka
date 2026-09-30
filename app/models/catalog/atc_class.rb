# frozen_string_literal: true

class Catalog::AtcClass < ApplicationRecord
  include Catalog::ProviderLinked
  include Catalog::Tree
  include Translatable

  translatable :name

  has_many :goods_groups, class_name: 'Catalog::GoodsGroup', inverse_of: :atc_class,
                          dependent: :restrict_with_exception

  validates :atc_code, presence: true
end

# == Schema Information
#
# Table name: catalog_atc_classes
#
#  id         :bigint           not null, primary key
#  atc_code   :string           not null
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#
# Indexes
#
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
