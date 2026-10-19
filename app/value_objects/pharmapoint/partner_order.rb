# frozen_string_literal: true

# An order as the partner keeps it: its numbers, its status as the partner wrote it, the drugstore, the lines and when
# it was made. `record` is the whole object the partner gave, kept with the order as it came.
class Pharmapoint::PartnerOrder < Data.define(
  :number,
  :customer_number,
  :status_name,
  :status_comment,
  :cancel_reason,
  :progress,
  :created_at,
  :updated_at,
  :drugstore_external_id,
  :lines,
  :record
)
end
