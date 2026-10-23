# frozen_string_literal: true

# Plans the reminders of items created or changed during the day, up to the end of the window the night already planned.
# Called after the save, so a reminder never runs before its data is visible. Empty until the reminders are planned
# (H24N-3455) and sent (H24N-3456).
class Pillbox::Reminders::TopUp
  def self.call(_items, _now) = nil
end
