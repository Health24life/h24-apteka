# frozen_string_literal: true

# Not based on ApplicationPolicy: that one is the admin's and allows everything.
class Pillbox::PlanPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def update? = record.active? || record.paused?

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = @scope.where(user_id: @user.id)
  end
end
