# frozen_string_literal: true

class Catalog::Instructions::ParsedInstruction < Data.define(:sections, :fallback_html)
  Section = Data.define(:position, :code, :anchor, :source_title, :body_html)

  def self.empty = new(sections: [], fallback_html: nil)

  def parsed? = sections.any?
end
