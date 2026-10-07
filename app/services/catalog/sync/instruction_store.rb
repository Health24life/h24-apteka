# frozen_string_literal: true

# Stores the instruction of a SKU split into sections. The split is made once, when the provider's text changes: an
# unchanged text is left alone, so the sections and their anchors stay the same between imports.
class Catalog::Sync::InstructionStore
  def self.call(goods, html) = new.call(goods, html)

  def call(goods, html)
    source = html.presence
    return if source == goods.instruction_source_html.presence

    parsed = Catalog::InstructionParser.call(source)
    # A reader must never see the card with the old sections gone and the new ones not yet there.
    Catalog::GoodsInstructionSection.transaction do
      goods.instruction_sections.destroy_all
      goods.update!(instruction_source_html: source, instruction_html_uk: parsed.fallback_html)
      parsed.sections.each { create_section(goods, it) }
    end
  end

  private

  def create_section(goods, section)
    goods.instruction_sections.create!(position: section.position, code: section.code, anchor: section.anchor,
                                       source_title: section.source_title, body_html_uk: section.body_html)
  end
end
