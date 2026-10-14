# frozen_string_literal: true

# The tree of categories comes from the provider: the admin changes only the SEO data and the slug of a category page.
class Catalog::CategoryPolicy < ApplicationPolicy
  def create? = false
  def update? = false
  def destroy? = false
  def seo? = true
  def slug? = true
end
