# frozen_string_literal: true

# Any redirect may be removed; only an editor's redirect may be led to another page, an automatic one follows its
# record by itself.
class Seo::RedirectPolicy < ApplicationPolicy
  def update? = record.is_a?(Class) || record.manual
  def import? = true
end
