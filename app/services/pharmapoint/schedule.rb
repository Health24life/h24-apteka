# frozen_string_literal: true

# The recurring jobs of the partner integration, as sidekiq-cron wants them. The periodicity of each is a cron
# expression in the environment; an empty one leaves that job off, which is how a kind of import is kept off until it
# is agreed with the provider.
class Pharmapoint::Schedule
  SOURCE = 'pharmapoint'
  # Name of the job => the environment variable with its cron, the default cron, the kind of data it passes over.
  SYNC_RUNS = {
    'catalog_sync_dictionaries' => [ 'SYNC_CRON_DICTIONARIES', '0 3 * * *', 'dictionaries' ],
    'catalog_sync_categories' => [ 'SYNC_CRON_CATEGORIES', '10 3 * * *', 'categories' ],
    'catalog_sync_goods_groups' => [ 'SYNC_CRON_GOODS_GROUPS', '', 'goods_groups' ],
    'catalog_sync_drugstores' => [ 'SYNC_CRON_DRUGSTORES', '30 3 * * *', 'drugstores' ]
  }.freeze
  LOG_CLEANUP = [ 'LOG_CLEANUP_CRON', '0 4 * * *' ].freeze

  def self.jobs(env = ENV) = new(env).jobs

  def self.sync_enabled?(kind, env = ENV) = new(env).sync_enabled?(kind)

  def initialize(env)
    @env = env
  end

  def jobs
    sync_jobs.merge(cleanup_job)
  end

  def sync_enabled?(kind)
    SYNC_RUNS.each_value.any? { |variable, default, run_kind| run_kind == kind && !cron(variable, default).nil? }
  end

  private

  def sync_jobs
    SYNC_RUNS.filter_map do |name, (variable, default, kind)|
      cron = cron(variable, default)
      [ name, job('Catalog::Sync::StartWorker', cron, args: [ kind ]) ] if cron
    end.to_h
  end

  def cleanup_job
    variable, default = LOG_CLEANUP
    cron = cron(variable, default)
    cron ? { 'provider_request_log_cleanup' => job('Pharmapoint::LogCleanupWorker', cron) } : {}
  end

  def job(klass, cron, args: [])
    { 'cron' => cron, 'class' => klass, 'queue' => 'default', 'args' => args }
  end

  def cron(variable, default) = @env.fetch(variable, default).to_s.strip.presence
end
