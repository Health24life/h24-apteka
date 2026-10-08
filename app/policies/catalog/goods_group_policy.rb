# frozen_string_literal: true

# Read-only in the admin apart from hiding from the storefront and bringing back.
class Catalog::GoodsGroupPolicy < ApplicationPolicy
  def visibility? = true
end
