# frozen_string_literal: true

D = Steep::Diagnostic

target :app do
  signature 'sig', '.rbs_rails'

  # Own code only. Rails code is not checked: the generated .rbs_rails gives own code the model types, and sig/
  # describes only the model methods and constants that own code uses.
  check 'app/services', 'app/service_objects', 'app/value_objects', 'app/validators', 'lib'
  ignore 'lib/tasks'

  configure_code_diagnostics(D::Ruby.default)
end
