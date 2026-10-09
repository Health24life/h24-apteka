# frozen_string_literal: true

# A drugstore. A list entry lacks the name, the outer code and the city id, so it is marked incomplete.
class Pharmapoint::Drugstore < Data.define(:external_id, :outer_id, :name, :complete, :legal_entity_name,
                                           :legal_entity_code, :week_working_hours, :work_with_reimbursement, :brand,
                                           :contacts, :location)
end
