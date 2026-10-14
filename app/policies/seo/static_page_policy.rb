# frozen_string_literal: true

# An editor writes the static pages; the home page is drawn by the front, so only its meta tags are set here.
class Seo::StaticPagePolicy < ApplicationPolicy
  def update? = !record.try(:home?)
  def destroy? = !record.try(:home?)
  def seo? = true
  def slug? = !record.try(:home?)
end
