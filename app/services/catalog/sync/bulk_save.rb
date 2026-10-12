# frozen_string_literal: true

# Saves a batch of the provider's records of one model in one insert, their translations and links with them. Only the
# records that changed are written; the links of the rest are moved on. A record that fails validation is logged and
# the batch goes on. When the database refuses the batch, it is rolled back and the same records are saved one by one.
class Catalog::Sync::BulkSave
  class Entry < Data.define(:external_id, :attributes, :payload); end

  def initialize(linker, tracker)
    @linker = linker
    @tracker = tracker
  end

  # Returns the saved records by the provider's id. Any error of the batch as a whole, from the database or from a value
  # it cannot take, sends the records one by one, where each failure is a record's own.
  def call(model, entries)
    return {} if entries.empty?

    records = build_all(model, entries)
    invalid = write(model, records.values.uniq)
  rescue StandardError => e
    fall_back(model, entries, e)
  else
    records.each { |entry, record| log_invalid(model, entry, record) if invalid.include?(record) }
    records.reject { |_, record| invalid.include?(record) }.transform_keys { it.external_id.to_s }
  end

  private

  def build_all(model, entries)
    @linker.preload(model, entries.map(&:external_id))
    entries.index_with { build(model, it) }
  end

  # Steep widens the record type of a generic call made from a generic method, so the record is passed on untyped.
  def build(model, entry)
    _ = @linker.build(model, entry.external_id, entry.attributes)
  end

  # A record whose own columns and translations are as they were is not written: only its link is moved on. The records
  # are validated here, as a save would, because validation may build translations that must be dropped before the
  # import writes them. Returns the records that failed validation.
  def write(model, records)
    changed, unchanged = records.partition(&:changed_for_autosave?)
    reserve_slugs(model, changed)
    invalid, valid = changed.partition(&:invalid?)
    valid.each { drop_empty_translations(it) }
    import(model, valid) if valid.any?
    move_links_on(unchanged)
    valid.each { reset_unloaded(it) }
    invalid
  end

  # Only the columns that changed are written over a record that is there: the rest (hidden, a link to the core, a
  # brand's picture) belong to others and may have changed since the batch was read.
  def import(model, records)
    children = { provider_links: %i[linkable_id synced_at], translations: translated_columns(model, records) }
    model.transaction(requires_new: true) do
      model.import(records, validate: false, recursive: true, on_duplicate_key_update: changed_columns(records),
                            recursive_on_duplicate_key_update: children.compact)
    end
  end

  def translated_columns(model, records)
    return unless model.reflect_on_association(:translations)

    changed_columns(records.flat_map { it.association(:translations).target })
  end

  def changed_columns(rows)
    columns = rows.first&.class&.column_names || []
    rows.flat_map(&:changed).uniq.select { columns.include?(it) }.map(&:to_sym)
  end

  # The import checks no uniqueness, so two new records of a batch must not get the same slug.
  def reserve_slugs(model, records)
    reserved = Set.new
    records.each do |record|
      next unless record.is_a?(Catalog::Sluggable) && record.new_record? && record.slug.blank?

      name = record.name_uk.presence or next
      reserved << (record.slug = Catalog::Slugs::Generator.call(name, scope: model, reserved:))
    end
  end

  # Reading a translated attribute that is blank builds a translation for each fallback locale. Mobility drops the empty
  # ones before a save, in a callback the import does not run.
  def drop_empty_translations(record)
    model = record.class
    return unless model.reflect_on_association(:translations) && model.is_a?(Mobility)

    mobility = model
    translations = record.association(:translations).reader
    translated = translations.klass.attribute_names.select { mobility.mobility_attribute?(it) }
    translations.destroy_empty_translations(translated)
  end

  def move_links_on(records)
    links = records.map { @linker.link_of(it) }
    return if links.empty?

    moved = { synced_at: links.first.synced_at, updated_at: Time.current }
    Provider::Link.where(id: links.map(&:id)).update_all(moved) # rubocop:disable Rails/SkipsModelValidations
  end

  # The import marks every has_many and has_one of a saved record as loaded, empty where it was not loaded before.
  def reset_unloaded(record)
    record.class.reflect_on_all_associations.each do |reflection|
      next if reflection.belongs_to? || %i[provider_links translations].include?(reflection.name)

      record.association(reflection.name).reset
    end
  end

  def log_invalid(model, entry, record)
    @tracker.record_failure(model.name, entry.external_id, ActiveRecord::RecordInvalid.new(record), entry.payload)
  end

  def fall_back(model, entries, error)
    Rails.error.report(error, handled: true, context: { source: 'catalog_sync_bulk_save', model: model.name })
    @linker.forget(model)
    one_by_one(model, entries)
  end

  def one_by_one(model, entries)
    entries.filter_map do |entry|
      record = @tracker.guard(model.name, entry.external_id, entry.payload) do
        @linker.sync(model, entry.external_id, entry.attributes)
      end
      [ entry.external_id.to_s, record ] if record
    end.to_h
  end
end
