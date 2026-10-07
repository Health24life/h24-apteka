# frozen_string_literal: true

namespace :one_time do
  namespace :catalog do
    desc 'First fill of the catalog: queue a fetch for each goods group id listed in a file (one per line)'
    task :pull_goods_groups, [ :path ] => :environment do |_task, args|
      path = args[:path] or abort 'Usage: rake one_time:catalog:pull_goods_groups[path/to/ids.txt]'

      result = Catalog::Sync::TopList.call(path)
      result.messages.each { warn it }
      puts "queued: #{result.enqueued}, already in the catalog or queued: #{result.present}, failed: #{result.failed}"
    end
  end
end
