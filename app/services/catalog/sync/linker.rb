# frozen_string_literal: true

# Saves a record of the provider's catalog and keeps its link to the provider. The link is what makes an import
# repeatable: the same external id always leads to the same record, and its time is when the record was last seen.
class Catalog::Sync::Linker
  def initialize(provider, now: Time.current)
    @provider = provider
    @now = now
  end

  # Finds the record the external id points to or builds a new one, applies the attributes and saves it. A block may
  # save the record instead, for models that have their own saver.
  def sync(model, external_id, attributes)
    record = model.find_linked(@provider, external_id) || model.new
    record.assign_attributes(attributes)
    block_given? ? yield(record) : record.save!
    link!(record, external_id)
    record
  end

  def find(model, external_id) = model.find_linked(@provider, external_id)

  # A reference to a record that must already exist; no id means no reference.
  def fetch(model, external_id)
    record = external_id && model.find_linked(@provider, external_id)
    raise Catalog::Sync::MissingReference, "#{model.name} #{external_id} is not imported" if external_id && !record

    record
  end

  def link!(record, external_id)
    link = Provider::Link.find_or_initialize_by(provider: @provider, linkable_type: record.class.name,
                                                external_id: external_id.to_s)
    link.linkable = record
    link.synced_at = @now
    link.save!
  end
end
