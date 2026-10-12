# frozen_string_literal: true

# Starts a run at an operator's request, under the same rules as the schedule: only a kind the schedule has on, and
# never a second run of a kind that is running.
class Catalog::Sync::ManualStart
  def self.call(kind, env: ENV)
    return :disabled unless Pharmapoint::Schedule.sync_enabled?(kind, env)

    Catalog::Sync::Starter.call(kind) ? :started : :already_running
  end
end
