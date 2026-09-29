# frozen_string_literal: true

begin
  require 'rbs_rails/rake_task'

  RbsRails::RakeTask.new
rescue LoadError
  # rbs_rails is a development-only gem; skip its tasks where it is not bundled (e.g. production).
end
