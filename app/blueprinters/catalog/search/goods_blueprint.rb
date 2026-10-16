# frozen_string_literal: true

# A row of the search: a SKU with the static data of its card, no prices, stock or images. A row with `ready: false` has
# no card yet and cannot be opened or put in the cart.
class Catalog::Search::GoodsBlueprint < Blueprinter::Base
  fields :ref, :provider, :ready, :id, :slug
  fields :name, :release_form, :dosage, :pack, :is_recipe, :is_strict_recipe, :trade_name

  field(:producer) { |hit| { name: hit.producer_name, country_code: hit.producer_country_code } }
  field(:group) { |hit| { ref: hit.group_ref, name: hit.group_name } }
end
