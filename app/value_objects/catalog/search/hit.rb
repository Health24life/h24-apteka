# frozen_string_literal: true

# A release form (SKU) a provider found, with the static data of its card only. `ready` tells whether the catalog
# already shows it, and then `id` and `slug` lead to its card.
class Catalog::Search::Hit < Data.define(
  :provider,
  :group_external_id,
  :external_id,
  :name,
  :release_form,
  :dosage,
  :pack,
  :trade_name,
  :producer_name,
  :producer_country_code,
  :group_name,
  :is_recipe,
  :is_strict_recipe,
  :ready,
  :id,
  :slug
)
  def ref = Catalog::Search::Ref.for(provider, group_external_id, external_id)

  def group_ref = Catalog::Search::Ref.for(provider, group_external_id)
end
