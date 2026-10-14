# frozen_string_literal: true

# Read-only in the admin apart from hiding from the storefront, bringing back and choosing the primary category.
class Catalog::Goods::GroupPolicy < ApplicationPolicy
  def visibility? = true
  def primary_category? = true
end
