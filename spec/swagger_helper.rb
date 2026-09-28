# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Health24 Apteka API',
        version: 'v1'
      },
      paths: {},
      components: {
        parameters: {
          header_lang: {
            name: 'Accept-Language',
            in: :header,
            schema: {
              type: :string,
              enum: I18n.available_locales
            }
          },
          auth_token: {
            name: :Authorization,
            in: :header,
            required: true,
            schema: { type: :string },
            description: "Bearer token (required unless the '.AspNet.ApplicationCookie' cookie is present)"
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
