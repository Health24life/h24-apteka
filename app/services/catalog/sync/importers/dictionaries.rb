# frozen_string_literal: true

# One step: the provider hands all dictionaries in a single answer.
class Catalog::Sync::Importers::Dictionaries
  def self.first_cursor = nil

  def self.call(tracker, client, linker, _cursor)
    Catalog::Sync::Savers::Dictionary.new(linker, tracker).call(client.dictionaries)
    nil
  end

  def self.skip(_tracker, _cursor) = nil
end
