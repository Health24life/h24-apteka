# frozen_string_literal: true

# Default policy (config.pundit_default_policy). Deliberately allow-by-default: only PACS servers/services
# are role-gated (their own policies), so every other resource keeps its pre-Pundit behaviour.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = true
  def show? = true
  def create? = true
  def new? = create?
  def update? = true
  def edit? = update?
  def destroy? = true

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end

    private

    attr_reader :user, :scope
  end
end
