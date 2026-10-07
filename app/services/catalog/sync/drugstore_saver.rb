# frozen_string_literal: true

# Saves a drugstore with its address. A list entry is poorer than a full record: it has no name and no outer code, so
# it never overwrites them and leaves a new drugstore marked incomplete until the full record arrives.
class Catalog::Sync::DrugstoreSaver
  def initialize(linker)
    @linker = linker
  end

  def call(record)
    raise Catalog::Sync::MissingData, 'the drugstore has no coordinates' unless record[:latitude] && record[:longitude]

    drugstore = @linker.sync(Catalog::Drugstore, record[:external_id], attributes(record)) do |drugstore|
      drugstore.incomplete = true if drugstore.new_record? && !record[:complete]
      drugstore.save!
    end
    save_address(drugstore, record)
    drugstore
  end

  private

  def attributes(record)
    attributes = { brand: brand(record[:brand]), drugstore_legal_entity_name: record[:legal_entity_name],
                   drugstore_legal_entity_code: record[:legal_entity_code], phone: record[:phone],
                   mobile_phone: record[:mobile_phone], email: record[:email],
                   week_working_hours: record[:week_working_hours],
                   work_with_reimbursement: record[:work_with_reimbursement], withdrawn: false }
    record[:complete] ? attributes.merge(full_record_attributes(record)) : attributes
  end

  def full_record_attributes(record)
    { name: record[:name], ext_drugstore_id: record[:outer_id], incomplete: false }
  end

  def brand(brand)
    return unless brand

    @linker.sync(Catalog::DrugstoreBrand, brand[:external_id], brand.slice(:name, :image_path).compact)
  end

  def save_address(drugstore, record)
    address = drugstore.address || drugstore.build_address
    address.update!(address: record[:address], city: record[:city], state: record[:state],
                    latitude: record[:latitude], longitude: record[:longitude])
  end
end
