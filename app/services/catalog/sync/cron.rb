# frozen_string_literal: true

# The periodicity of each kind of import, a cron expression in the environment. An empty one leaves the kind off, which
# is how a kind is kept off until it is agreed with the provider: config/schedule.yml then skips its job, and an
# operator cannot start it by hand either.
module Catalog::Sync::Cron
  # Kind of data => the environment variable with its cron, the default cron.
  KINDS = {
    'dictionaries' => [ 'SYNC_CRON_DICTIONARIES', '0 3 * * *' ],
    'categories' => [ 'SYNC_CRON_CATEGORIES', '10 3 * * *' ],
    'goods_groups' => [ 'SYNC_CRON_GOODS_GROUPS', '' ],
    'drugstores' => [ 'SYNC_CRON_DRUGSTORES', '30 3 * * *' ]
  }.freeze

  def self.of(kind, env = ENV)
    variable, default = KINDS[kind]
    env.fetch(variable, default).to_s.strip.presence if variable
  end

  def self.enabled?(kind, env = ENV) = !of(kind, env).nil?
end
