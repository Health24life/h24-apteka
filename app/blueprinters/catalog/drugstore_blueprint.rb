# frozen_string_literal: true

# A drugstore as the directory knows it, with what the law asks to show by it: the full name of the legal entity, its
# EDRPOU code and the working hours. The week schedule starts on Monday.
class Catalog::DrugstoreBlueprint < Blueprinter::Base
  fields :id, :name, :week_working_hours, :work_with_reimbursement

  field(:legal_entity) do |drugstore|
    { name: drugstore.drugstore_legal_entity_name, code: drugstore.drugstore_legal_entity_code }
  end
  field(:phone) { |drugstore| drugstore.phone || drugstore.mobile_phone }

  association :brand, blueprint: Catalog::Drugstore::BrandBlueprint
  association :address, blueprint: Catalog::Drugstore::AddressBlueprint
end
