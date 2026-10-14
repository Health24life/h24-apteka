# frozen_string_literal: true

namespace :dev do
  desc 'Fill the development database with sample data of every screen of the admin'
  task samples: :environment do
    abort 'dev:samples fills the development database only' unless Rails.env.development?

    # Loaded here, after the environment: the samples name the models.
    require_relative 'dev/samples'

    DevSamples.run
    puts 'Sample data is ready: sign in to /admin with the seed admin.'
  end
end
