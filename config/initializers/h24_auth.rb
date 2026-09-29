# frozen_string_literal: true

H24Auth.configure do |c|
  c.database :h24_core

  c.expose :user, claim: 'nameid', model: 'H24Core::User'
  c.expose :phone, claim: 'unique_name'
end
