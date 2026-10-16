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
        securitySchemes: {
          # The Health24 session token. The API takes it from this header only; a request without it is a guest.
          bearer: { type: :http, scheme: :bearer, bearerFormat: :JWT }
        },
        schemas: {
          error: {
            type: :object,
            required: %w[error],
            properties: {
              error: {
                type: :object,
                required: %w[code message],
                properties: {
                  code: { type: :string, description: 'Stable machine code' },
                  message: { type: :string, description: 'Message in Ukrainian' }
                }
              }
            }
          }
        },
        parameters: {
          header_lang: {
            name: 'Accept-Language',
            in: :header,
            schema: {
              type: :string,
              enum: I18n.available_locales
            }
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
