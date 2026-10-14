# frozen_string_literal: true

# Sample data for a local look at every screen of the admin, enough of it to page through lists and search in
# selects: dictionaries and a catalog with instructions, pharmacies, carts and sent orders, sync runs with failures and
# request logs, the history of hiding and of the primary category, and the SEO data with its history by several
# admins. Written through the models, so it passes the rules of the application. Safe to run again: each part looks
# its records up and adds only what is missing. Development only.
module DevSamples
  module_function

  # Each part looks up what an earlier part made, so they run in this order.
  PARTS = %w[Dictionaries Catalog Drugstores Orders Operations].freeze

  def run
    admins = Admins.call
    provider = Provider.find_by!(code: 'pharmapoint')
    as(admins.first) { PARTS.each { const_get(it).call(provider) } }
    History.call(admins)
    Seo.call(admins)
  end

  # Versions written inside are by the given admin, as if made in the admin.
  def as(admin, &) = PaperTrail.request(controller_info: { author: admin }, whodunnit: admin&.id, &)

  # A link of the provider to the record, as the import would make it, unless there is one.
  def link(provider, record, external_id: nil, attrs: {})
    Provider::Link.find_by(provider:, linkable: record) ||
      Provider::Link.create!(provider:, linkable: record, external_id: external_id || SecureRandom.hex(16), attrs:,
                             synced_at: rand(1..48).hours.ago)
  end

  def by_name(model, name) = model.where("name->>'uk' = ?", name).first
end

require_relative 'samples/admins'
require_relative 'samples/dictionaries'
require_relative 'samples/catalog_data'
require_relative 'samples/catalog'
require_relative 'samples/goods'
require_relative 'samples/drugstores'
require_relative 'samples/orders'
require_relative 'samples/operations'
require_relative 'samples/history'
require_relative 'samples/seo'
