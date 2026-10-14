# frozen_string_literal: true

# Read-only in the admin apart from hiding from the storefront and bringing back, and the SEO data and slug of its page.
class Catalog::GoodsPolicy < ApplicationPolicy
  def visibility? = true
  def seo? = true
  def slug? = true
end
