# frozen_string_literal: true

# Saves a drugstore with its address. A list entry is poorer than a full record: it has no name and no outer code, so
# it never overwrites them and leaves a new drugstore marked incomplete until the full record arrives.
class Catalog::Sync::DrugstoreSaver
  def initialize(linker)
    @linker = linker
  end

  def call(record)
    location = record.location
    raise Catalog::Sync::MissingData, 'the drugstore has no coordinates' unless location.latitude && location.longitude

    drugstore = @linker.sync(Catalog::Drugstore, record.external_id, attributes(record)) do |drugstore|
      drugstore.incomplete = true if drugstore.new_record? && !record.complete
      drugstore.save!
    end
    save_address(drugstore, location)
    drugstore
  end

  private

  def attributes(record)
    attributes = { brand: brand(record.brand), drugstore_legal_entity_name: record.legal_entity_name,
                   drugstore_legal_entity_code: record.legal_entity_code, week_working_hours: record.week_working_hours,
                   work_with_reimbursement: record.work_with_reimbursement, withdrawn: false }
                 .merge(contact_attributes(record.contacts))
    record.complete ? attributes.merge(full_record_attributes(record)) : attributes
  end

  def contact_attributes(contacts)
    { phone: contacts.phone, mobile_phone: contacts.mobile_phone, email: contacts.email }
  end

  def full_record_attributes(record) = { name: record.name, ext_drugstore_id: record.outer_id, incomplete: false }

  def brand(brand)
    return unless brand

    @linker.sync(Catalog::DrugstoreBrand, brand.external_id, { name: brand.name, image_path: brand.image_path }.compact)
  end

  def save_address(drugstore, location)
    address = drugstore.address || drugstore.build_address
    address.update!(address: location.address, city: location.city, state: location.state,
                    latitude: location.latitude, longitude: location.longitude)
  end
end
