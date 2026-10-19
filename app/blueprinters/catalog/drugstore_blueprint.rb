# frozen_string_literal: true

# A drugstore as the directory knows it, with what the law asks to show by it: the full name of the legal entity, its
# EDRPOU code and the working hours. The week schedule starts on Monday.
class Catalog::DrugstoreBlueprint < Blueprinter::Base
  fields :id, :name, :week_working_hours, :work_with_reimbursement

  field(:brand) { |drugstore| drugstore.brand && { name: drugstore.brand.name } }
  field(:legal_entity) do |drugstore|
    { name: drugstore.drugstore_legal_entity_name, code: drugstore.drugstore_legal_entity_code }
  end
  field(:address) { |drugstore| drugstore.address&.address }
  field(:latitude) { |drugstore| drugstore.address&.latitude&.to_f }
  field(:longitude) { |drugstore| drugstore.address&.longitude&.to_f }
  field(:phone) { |drugstore| drugstore.phone || drugstore.mobile_phone }
  # Booking goes only to the drugstores of the pilot.
  field(:booking_available) { |drugstore| Orders::Bookings.config.allowed?(drugstore.id) }
end
