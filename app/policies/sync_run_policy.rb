# frozen_string_literal: true

# Read-only in the admin apart from starting a run by hand.
class SyncRunPolicy < ApplicationPolicy
  def start? = true
end
