# frozen_string_literal: true

# A removed filter keeps its address and its history but no longer changes: it comes back by a restore first. No filter
# leaves the database, so its address keeps answering.
class Seo::FilterPolicy < ApplicationPolicy
  def update? = !removed?
  def destroy? = false
  def seo? = update?
  def slug? = update?
  def publish? = update?
  def unpublish? = update?
  def remove? = update?
  def restore? = removed?

  private

  def removed? = record.try(:removed?) == true
end
