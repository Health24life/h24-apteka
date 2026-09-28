# frozen_string_literal: true

H24Auth.configure do |c|
  c.database :h24_core

  c.expose :user, claim: 'nameid', model: 'H24Auth::User'
  c.expose :employee, claim: 'employee_id', model: 'H24Auth::Employee'
  c.expose :legal_entity, claim: 'legal_entity_id', model: 'H24Auth::LegalEntity'
  c.expose :employee_type
  c.expose :employee_id
  c.expose :legal_entity_id
end
