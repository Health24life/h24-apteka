# frozen_string_literal: true

# Saves a record of the provider's catalog and keeps its link to the provider. The link is what makes an import
# repeatable: the same external id always leads to the same record, and its time is when the record was last seen.
# A linker lives for one step, so the records it has looked up are kept for the step and not asked for again.
class Catalog::Sync::Linker
  def initialize(provider, now: Time.current)
    @provider = provider
    @now = now
    @records = {}
  end

  # Finds the record the external id points to or builds a new one, applies the attributes and saves it. A block may
  # save the record instead, for models that have their own saver.
  # A record seen missing earlier in the step may have been linked since by another worker, so a save looks again.
  def sync(model, external_id, attributes)
    record = @records[key(model, external_id)] || model.find_linked(@provider, external_id) || model.new
    record.assign_attributes(attributes)
    block_given? ? yield(record) : record.save!
    link!(record, external_id)
    @records[key(model, external_id)] = record
  end

  def find(model, external_id) = lookup(model, external_id)

  # A reference to a record that must already exist; no id means no reference.
  def fetch(model, external_id)
    record = external_id && lookup(model, external_id)
    raise Catalog::Sync::MissingReference, "#{model.name} #{external_id} is not imported" if external_id && !record

    record
  end

  # Looks up the records of a batch, with their links and translations, in one query.
  def preload(model, external_ids)
    wanted = external_ids.map(&:to_s).uniq.reject { @records.key?(key(model, it)) }
    return if wanted.empty?

    linked(model, wanted).each { |record| @records[key(model, link_of(record).external_id)] = record }
    wanted.each { @records[key(model, it)] ||= nil }
  end

  # The record with the attributes applied and its link moved on, all in memory, for a bulk save to write.
  def build(model, external_id, attributes)
    record = lookup(model, external_id) || model.new
    record.assign_attributes(attributes)
    links = record.provider_links
    link = links.find { it.provider_id == @provider.id } || links.build(provider: @provider)
    link.assign_attributes(external_id: external_id.to_s, synced_at: @now)
    @records[key(model, external_id)] = record
  end

  def link_of(record)
    record.provider_links.find { it.provider_id == @provider.id } ||
      raise(KeyError, "#{record.class.name} #{record.id} has no link to the provider")
  end

  # Drops what is known of a model, after a bulk save of it was rolled back.
  def forget(model) = @records.delete_if { |(name, _), _| name == model.name }

  def link!(record, external_id)
    link = Provider::Link.find_or_initialize_by(
      provider: @provider,
      linkable_type: record.class.name,
      external_id: external_id.to_s
    )
    link.linkable = record
    link.synced_at = @now
    link.save!
  end

  private

  def lookup(model, external_id)
    key = key(model, external_id)
    return @records[key] if @records.key?(key)

    @records[key] = model.find_linked(@provider, external_id)
  end

  def linked(model, external_ids)
    model
      .includes(*preloaded_associations(model))
      .where(provider_links: { provider_id: @provider.id, external_id: external_ids })
      .to_a
  end

  def key(model, external_id) = [ model.name, external_id.to_s ]

  def preloaded_associations(model)
    [ :provider_links, (:translations if model.reflect_on_association(:translations)) ].compact
  end
end
