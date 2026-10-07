# frozen_string_literal: true

# The category tree: every node carries its children, so the parent is the node it sits in.
class Pharmapoint::Readers::Categories
  def self.call(body) = new.call(body)

  def call(body) = Pharmapoint::Readers::Base.list(Pharmapoint::Readers::Base.envelope(body)).filter_map { node(it) }

  private

  def node(record)
    return unless record.is_a?(Hash)

    external_id = Pharmapoint::Readers::Base.external_id(record['id'])
    return unless external_id

    { external_id:, name: Pharmapoint::Readers::Base.name(record),
      children: Pharmapoint::Readers::Base.list(record['children']).filter_map { node(it) } }
  end
end
