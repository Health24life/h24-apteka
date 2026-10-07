# frozen_string_literal: true

# The category tree: every node carries its children, so the parent is the node it sits in.
class Pharmapoint::Readers::Categories
  include Pharmapoint::Readers::Base

  def self.call(body) = new.call(body)

  def call(body) = list(envelope(body)).filter_map { node(it) }

  private

  def node(record)
    return unless record.is_a?(Hash)

    external_id = id_at(record, 'id')
    return unless external_id

    children = list_at(record, 'children').filter_map { node(it) }
    Pharmapoint::CategoryNode.new(external_id:, name: name(record), children:)
  end
end
