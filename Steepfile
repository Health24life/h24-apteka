# frozen_string_literal: true

D = Steep::Diagnostic

target :app do
  signature 'sig', '.rbs_rails'

  # Models and own code. What rbs_rails can generate (attributes, associations, scopes, enum) comes from .rbs_rails;
  # what is written by hand (constants, custom methods, concerns, the DSL they add) is described in sig/.
  check 'app/models', 'app/models_readonly', 'app/lib', 'app/services', 'app/service_objects', 'app/value_objects',
        'app/validators', 'lib'
  ignore 'lib/tasks'

  configure_code_diagnostics(D::Ruby.default)
end
