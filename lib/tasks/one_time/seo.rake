# frozen_string_literal: true

namespace :one_time do
  desc 'Add the general SEO template of each page type that has none'
  task seo_default_templates: :environment do
    added = Seo::Templates::Defaults.call
    puts added.any? ? "added: #{added.join(', ')}" : 'every page type already has a general template'
  end
end
