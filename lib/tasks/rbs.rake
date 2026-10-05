# frozen_string_literal: true

begin
  require 'rbs_rails/rake_task'

  RbsRails::RakeTask.new { it.signature_root_dir = Rails.root.join('.rbs_rails') }
rescue LoadError
  # rbs_rails is a development-only gem; skip its tasks where it is not bundled (e.g. production).
end
