# frozen_string_literal: true

# The general template of a page type stays: a page without a narrower one takes its texts from it.
class Seo::TemplatePolicy < ApplicationPolicy
  def destroy? = !record.try(:general?)
end
