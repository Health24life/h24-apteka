# frozen_string_literal: true

# Removes the entries of the request log that outlived the period of their category. It deletes in batches, so it does
# not hold the table while the log is being written.
class Pharmapoint::LogRetention
  BATCH = 1000

  def self.call(config: Pharmapoint::Config.current, now: Time.current) = new(config, now).call

  def initialize(config, now)
    @config = config
    @now = now
  end

  def call = ProviderRequestLog.categories.values.sum { purge(it) }

  private

  def purge(category)
    cutoff = @now - @config.retention_for(category)
    removed = 0
    loop do
      ids = ProviderRequestLog.where(category:).older_than(cutoff).limit(BATCH).pluck(:id)
      break if ids.empty?

      removed += ProviderRequestLog.where(id: ids).delete_all
    end
    removed
  end
end
