# frozen_string_literal: true

class Catalog::Producer < ApplicationRecord
  include Catalog::ProviderLinked

  belongs_to :core_country, class_name: 'H24Core::Classification::Address::Country', foreign_key: :country_code,
                            primary_key: :code, optional: true, inverse_of: false

  has_many :goods_groups, class_name: 'Catalog::Goods::Group', inverse_of: :producer,
                          dependent: :restrict_with_exception

  normalizes :country_code, with: -> { it.presence }

  validates :name, presence: true
  validates :country_code, format: { with: /\A[A-Z]{2}\z/ }, allow_blank: true
end

# == Schema Information
#
# Table name: catalog_producers
#
#  id           :bigint           not null, primary key
#  country      :string
#  country_code :string(2)
#  name         :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Check Constraints
#
#  catalog_producers_country_code_check  (country_code IS NULL OR country_code::text ~ '^[A-Z]{2}$'::text)
#
