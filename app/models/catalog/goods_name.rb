# frozen_string_literal: true

class Catalog::GoodsName < ApplicationRecord
  include Catalog::ProviderLinked

  has_many :goods_groups, class_name: 'Catalog::GoodsGroup', inverse_of: :goods_name,
                          dependent: :restrict_with_exception

  validates :name, presence: true
end

# == Schema Information
#
# Table name: catalog_goods_names
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
