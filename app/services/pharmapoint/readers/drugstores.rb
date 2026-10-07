# frozen_string_literal: true

# Drugstores. The list answer is the poorest one: it has no name, no outer code of the drugstore and no city id, so
# such a record is marked incomplete until the single-drugstore answer fills it in. Distance and today's working
# hours depend on the request, so they are not read.
class Pharmapoint::Readers::Drugstores
  FIELDS = {
    name: %w[name text], outer_id: %w[ext_drugstore_id text], legal_entity_name: %w[legal_entity_name text],
    legal_entity_code: %w[legal_entity_code text], address: %w[address text], city: %w[city text],
    state: %w[state text], phone: %w[phone text], mobile_phone: %w[mobile_phone text], email: %w[email text],
    work_with_reimbursement: %w[work_with_reimbursement flag]
  }.freeze
  # What a record needs to be more than a list entry.
  COMPLETENESS_KEYS = %w[name ext_drugstore_id city_id].freeze

  def self.list(body) = new.list(body)

  # A single drugstore comes back as an array of one element.
  def self.one(body) = new.one(body)

  def list(body) = base.list(base.envelope(body)).filter_map { drugstore(it) }

  def one(body)
    data = base.envelope(body)
    drugstore(data.is_a?(Array) ? data.first : data) ||
      raise(Pharmapoint::InvalidResponse, 'the answer has no drugstore')
  end

  private

  def base = Pharmapoint::Readers::Base

  def drugstore(record)
    return unless record.is_a?(Hash)

    external_id = base.external_id(record['id'])
    return unless external_id

    { external_id:, complete: complete?(record), brand: brand(record['drugstore_brand']),
      week_working_hours: week_hours(record['week_working_hours']) }
      .merge(base.pick(record, FIELDS), coordinates(record['coordinates']))
  end

  def complete?(record) = COMPLETENESS_KEYS.all? { base.text(record[it]) }

  def coordinates(record)
    record = base.hash_or_empty(record)
    { latitude: base.float(record['latitude']), longitude: base.float(record['longitude']) }
  end

  # The partner does not say which day the week starts with, so the seven entries are kept in the given order.
  def week_hours(value) = base.list(value).map { base.text(it) }

  def brand(record)
    record = base.hash_or_empty(record)
    external_id = base.external_id(record['id'])
    { external_id:, name: base.text(record['name']), image_path: base.text(record['image_url']) } if external_id
  end
end
