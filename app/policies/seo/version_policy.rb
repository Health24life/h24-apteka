# frozen_string_literal: true

# The history of the SEO data is read only: a version is never created, changed or removed from the admin.
class Seo::VersionPolicy < ApplicationPolicy
  def create? = false
  def update? = false
  def destroy? = false
end
