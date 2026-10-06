# frozen_string_literal: true

# Splits a provider's instruction, a flat run of paragraphs, into the known sections. A heading is a paragraph
# that opens with bold text; bold text that is not a known heading stays inside the current section.
class Catalog::InstructionParser
  ALLOWED_TAGS = %w[p b i sup sub br ul li].freeze
  # The safe-list sanitizer drops these tags but keeps their text.
  DROPPED_WITH_CONTENT = 'script, style'
  MIN_SECTIONS = 2
  # Punctuation left outside the bold heading, as in <b>Склад</b>: ... Nokogiri writes a non-breaking space as &nbsp;.
  LEADING_PUNCTUATION = /\A(?:[[:space:].:]|&nbsp;)+/

  def self.call(html) = new.call(html)

  def call(html)
    clean = sanitize(html.to_s)
    fragment = Nokogiri::HTML5.fragment(clean)
    return Catalog::ParsedInstruction.empty if fragment.text.blank?

    sections = split(fragment)
    return Catalog::ParsedInstruction.new(sections: [], fallback_html: clean) if sections.size < MIN_SECTIONS

    Catalog::ParsedInstruction.new(sections:, fallback_html: nil)
  end

  private

  def sanitize(html)
    fragment = Nokogiri::HTML5.fragment(html)
    fragment.css(DROPPED_WITH_CONTENT).each(&:remove)
    Rails::HTML5::SafeListSanitizer.new.sanitize(fragment.to_html, tags: ALLOWED_TAGS, attributes: []).to_s.strip
  end

  def split(fragment)
    # @type var drafts: Array[draft]
    drafts = []
    fragment.children.each { collect(it, drafts) }
    number(drafts.reject { it[:body].empty? })
  end

  def collect(node, drafts)
    heading = heading_of(node)
    code = heading && Catalog::InstructionSections.code_for(heading.text)
    if heading && code
      drafts << { code:, source_title: heading.text.squish, body: [ rest_after(node, heading) ].compact }
    elsif (current = drafts.last) && significant?(node)
      current[:body] << node.to_html
    end
  end

  def heading_of(node)
    return unless node.element? && node.name == 'p'

    first = node.children.find { significant?(it) }
    first if first&.element? && first.name == 'b'
  end

  def rest_after(paragraph, heading)
    rest = paragraph.children.drop_while { !it.equal?(heading) }.drop(1)
    html = rest.map(&:to_html).join.sub(LEADING_PUNCTUATION, '').strip
    "<p>#{html}</p>" if Nokogiri::HTML5.fragment(html).text.present?
  end

  def significant?(node) = !(node.text? && node.text.blank?)

  def number(drafts)
    seen = Hash.new(0)
    drafts.each_with_index.map do |draft, index|
      code = draft[:code]
      seen[code] += 1
      Catalog::ParsedInstruction::Section.new(
        position: index + 1, code:, anchor: seen[code] == 1 ? code : "#{code}-#{seen[code]}",
        source_title: draft[:source_title], body_html: draft[:body].join
      )
    end
  end
end
