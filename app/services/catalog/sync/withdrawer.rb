# frozen_string_literal: true

# Marks as withdrawn the links of the goods groups and SKU a full successful run did not see. Nothing is deleted, and a
# record that failed in this very run keeps its earlier version instead of being taken off the shelf.
#
# A record is withdrawn only once no enabled provider has a live link to it: one provider dropping a record another one
# still sends must not take it off the shelf. A provider that sends it again revives its link and brings it back.
class Catalog::Sync::Withdrawer
  MODELS = [ Catalog::Goods::Group, Catalog::Goods ].freeze

  def self.call(run) = new(run).call

  def initialize(run)
    @run = run
  end

  def call = MODELS.each { withdraw(it) }

  private

  # rubocop:disable-next Rails/SkipsModelValidations -- a run marks every unseen record at once.
  def withdraw(model)
    unseen = unseen(model)
    unseen.where(withdrawn_at: nil).update_all(withdrawn_at: Time.current)
    model.where(id: unseen.select(:linkable_id)).where.not(id: live(model)).update_all(withdrawn: true)
  end

  def unseen(model)
    Provider::Link.where(provider_id: @run.provider_id, linkable_type: model.name)
                  .where(synced_at: ...@run.started_at).where.not(external_id: failed_ids(model))
  end

  def live(model)
    Provider::Link.where(linkable_type: model.name, withdrawn_at: nil, provider: Provider.enabled).select(:linkable_id)
  end

  def failed_ids(model) = @run.failures.where(entity_type: model.name).select(:external_id)
end
