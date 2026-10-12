# frozen_string_literal: true

# Drugstores. The list answer is the poorest one: it has no name, no outer code of the drugstore and no city id, so
# such a record is marked incomplete until the single-drugstore answer fills it in. Distance and today's working
# hours depend on the request, so they are not read.
class Pharmapoint::Readers::Drugstores
  include Pharmapoint::Readers::Base

  # What a record needs to be more than a list entry.
  COMPLETENESS_KEYS = %w[name ext_drugstore_id city_id].freeze

  def self.list(body) = new.many(body)

  # A single drugstore comes back as an array of one element.
  def self.one(body) = new.one(body)

  def many(body) = list(envelope(body)).filter_map { drugstore(it) }

  def one(body)
    data = envelope(body)
    drugstore(data.is_a?(Array) ? data.first : data) ||
      raise(Pharmapoint::InvalidResponse, 'the answer has no drugstore')
  end

  private

  def drugstore(record)
    return unless record.is_a?(Hash)

    external_id = id_at(record, 'id')
    build(external_id, record) if external_id
  end

  def build(external_id, record)
    Pharmapoint::Drugstore.new(
      external_id:, outer_id: text_at(record, 'ext_drugstore_id'), name: text_at(record, 'name'),
      complete: complete?(record), legal_entity_name: text_at(record, 'legal_entity_name'),
      legal_entity_code: text_at(record, 'legal_entity_code'), week_working_hours: week_hours(record),
      work_with_reimbursement: affirmative_at?(record, 'work_with_reimbursement'),
      brand: brand(record['drugstore_brand']), contacts: contacts(record), location: location(record)
    )
  end

  def complete?(record) = COMPLETENESS_KEYS.all? { text_at(record, it) }

  def contacts(record)
    Pharmapoint::Contacts.new(phone: text_at(record, 'phone'), mobile_phone: text_at(record, 'mobile_phone'),
                              email: text_at(record, 'email'))
  end

  def location(record)
    coordinates = hash_at(record, 'coordinates')
    Pharmapoint::Location.new(address: text_at(record, 'address'), city: text_at(record, 'city'),
                              state: text_at(record, 'state'), latitude: float_at(coordinates, 'latitude'),
                              longitude: float_at(coordinates, 'longitude'))
  end

  # The partner does not say which day the week starts with, so the seven entries are kept in the given order.
  def week_hours(record) = list_at(record, 'week_working_hours').map { text(it) }

  def brand(value)
    record = hash_or_empty(value)
    external_id = id_at(record, 'id')
    return unless external_id

      Pharmapoint::Brand.new(external_id:, name: text_at(record, 'name'),
                             image_path: text_at(record, 'image_url'))
  end
end
