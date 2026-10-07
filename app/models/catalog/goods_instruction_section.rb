# frozen_string_literal: true

class Catalog::GoodsInstructionSection < ApplicationRecord
  include Translatable

  translatable :body_html, backend: :table

  belongs_to :goods, class_name: 'Catalog::Goods', inverse_of: :instruction_sections

  validates :source_title, :body_html_uk, presence: true
  validates :code, inclusion: { in: Catalog::InstructionSections::CODES }
  validates :anchor, presence: true, format: { with: Catalog::Sluggable::FORMAT }, uniqueness: { scope: :goods_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1 },
                       uniqueness: { scope: :goods_id }

  def title = I18n.t(code, scope: 'catalog.instruction_sections')
end

# == Schema Information
#
# Table name: catalog_goods_instruction_sections
#
#  id           :bigint           not null, primary key
#  anchor       :string           not null
#  code         :string           not null
#  position     :integer          not null
#  source_title :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  goods_id     :bigint           not null
#
# Indexes
#
#  index_catalog_instruction_sections_on_goods_and_anchor    (goods_id,anchor) UNIQUE
#  index_catalog_instruction_sections_on_goods_and_position  (goods_id,position) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (goods_id => catalog_goods.id)
#
# Check Constraints
#
#  catalog_goods_instruction_sections_anchor_check    (anchor::text ~ '^[a-z0-9]+(-[a-z0-9]+)*$'::text)
#  catalog_goods_instruction_sections_position_check  ("position" >= 1)
#
