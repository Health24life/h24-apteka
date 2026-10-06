# frozen_string_literal: true

Catalog::ParsedInstruction = Data.define(:sections, :fallback_html)

class Catalog::ParsedInstruction
  Section = Data.define(:position, :code, :anchor, :source_title, :body_html)

  def self.empty = new(sections: [], fallback_html: nil)

  def parsed? = sections.any?
end
