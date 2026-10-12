# frozen_string_literal: true

# The recurring jobs of the SEO data, as sidekiq-cron wants them. An empty cron expression leaves that job off.
class Seo::Schedule
  SOURCE = 'seo'
  # Name of the job => the worker, the environment variable with its cron and the default cron.
  JOBS = {
    'seo_sitemap' => [ 'Seo::SitemapWorker', 'SEO_SITEMAP_CRON', '0 5 * * *' ],
    'seo_redirect_cleanup' => [ 'Seo::RedirectCleanupWorker', 'SEO_REDIRECT_CLEANUP_CRON', '40 4 * * *' ]
  }.freeze

  def self.jobs(env = ENV)
    # @type var args: Array[String]
    args = []
    JOBS.filter_map do |name, (klass, variable, default)|
      cron = env.fetch(variable, default).to_s.strip.presence or next
      [ name, { 'cron' => cron, 'class' => klass, 'queue' => 'default', 'args' => args } ]
    end.to_h
  end
end
