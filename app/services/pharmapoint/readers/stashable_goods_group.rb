# frozen_string_literal: true

# A goods group of the provider's answer kept as it came, for a later save that need not ask the provider again: the
# live fields go, and a record lacking what such a save would wipe in the catalog is not kept at all.
class Pharmapoint::Readers::StashableGoodsGroup
  include Pharmapoint::Readers::Base

  # The fields of a group and of its SKU that depend on the drugstore and the moment.
  LIVE_KEYS = %w[
    online_price
    drugstore_price
    quantity
    nds
    preorder
    is_preorder
    drugstores_count_available
    drugstores_count_all
    offers
    price_min
    drugstore_count
  ].freeze

  def self.call(record) = new.call(record)

  # The group as the provider gave it, without the live fields, for a later save that need not ask the provider again.
  # Nil when the record lacks what such a save would wipe in the catalog: the SKU, the instruction of any of them or the
  # categories of the group.
  def call(record)
    return unless record.is_a?(Hash) && id_at(record, 'id') && list_at(record, 'goods_categories').any?

    forms = complete_forms(list_at(record, 'release_forms'))
    record.except(*LIVE_KEYS).merge('release_forms' => forms.map { it.except(*LIVE_KEYS) }) if forms
  end

  private

  # The SKU when there are some and every one has its instruction.
  def complete_forms(values)
    forms = values.filter_map { it if it.is_a?(Hash) && text_at(it, 'instruction') }
    forms if forms.any? && forms.size == values.size
  end
end
