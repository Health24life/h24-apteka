# frozen_string_literal: true

# A blueprint declares the associations it reads with `preload:` on its fields, and the extension preloads them when a
# relation is rendered, as in system_ruby. `preload: false` in the options of a render turns it off, for data already
# preloaded. A single record is rendered as it is.
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::Preloader.new do |_object, _blueprint, _view, options|
    options[:preload] != false
  end
end
