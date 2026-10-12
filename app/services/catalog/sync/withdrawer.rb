# frozen_string_literal: true

# Marks as withdrawn the goods groups and SKU a full successful run did not see. Nothing is deleted, and a record that
# failed in this very run keeps its earlier version instead of being taken off the shelf.
class Catalog::Sync::Withdrawer
  MODELS = [ Catalog::Goods::Group, Catalog::Goods ].freeze

  def self.call(run) = new(run).call

  def initialize(run)
    @run = run
  end

  def call = MODELS.each { withdraw(it) }

  private

  def withdraw(model)
    unseen = Provider::Link.where(provider_id: @run.provider_id, linkable_type: model.name)
                           .where(synced_at: ...@run.started_at).where.not(external_id: failed_ids(model))
    model.where(id: unseen.select(:linkable_id)).update_all(withdrawn: true) # rubocop:disable Rails/SkipsModelValidations
  end

  def failed_ids(model) = @run.failures.where(entity_type: model.name).select(:external_id)
end
