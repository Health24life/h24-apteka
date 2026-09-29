# frozen_string_literal: true

D = Steep::Diagnostic

target :app do
  signature 'sig'

  check 'app', 'lib'
  ignore 'app/admin', 'lib/tasks'

  configure_code_diagnostics(D::Ruby.default)
end
