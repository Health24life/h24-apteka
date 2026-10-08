# frozen_string_literal: true

# Read-only in the admin apart from hiding from the storefront and bringing back. The options are what the drugstore
# filter of the orders searches.
class Catalog::DrugstorePolicy < ApplicationPolicy
  def visibility? = true
  def all_options? = true
end
