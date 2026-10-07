# frozen_string_literal: true

# One search point per step; the cursor is the index of the point. A drugstore the list gives only in part is
# queued to be completed from its own record.
class Catalog::Sync::Importers::Drugstores
  def self.first_cursor = 0

  def self.call(tracker, client, linker, cursor)
    points = Pharmapoint::Config.current.search_points
    point = points.fetch(cursor.to_i) { raise Pharmapoint::ConfigurationError, 'no drugstore search points are configured' }
    saver = Catalog::Sync::DrugstoreSaver.new(linker)
    client.drugstores(point).each { |record| save(tracker, saver, record) }
    following(cursor, points.size)
  end

  def self.skip(_tracker, cursor) = following(cursor, Pharmapoint::Config.current.search_points.size)

  def self.following(cursor, size) = cursor.to_i + 1 < size ? cursor.to_i + 1 : nil

  def self.save(tracker, saver, record)
    saved = tracker.guard('Catalog::Drugstore', record.external_id, record) do
      saver.call(record)
      tracker.processed!
    end
    Catalog::Sync::Pull.enqueue(:drugstore, record.external_id) if saved && !record.complete
  end
end
