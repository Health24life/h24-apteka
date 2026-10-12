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
          },
          seo_page: {
            type: :object,
            required: %w[status location title description h1 robots breadcrumbs seo_text],
            properties: {
              status: { type: :integer, enum: [ 200, 301, 404, 410 ], description: 'State of the page' },
              location: { type: :string, nullable: true, description: 'Path to redirect to, for 301 only' },
              title: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              h1: { type: :string, nullable: true },
              robots: { type: :string, nullable: true, example: 'index, follow' },
              breadcrumbs: {
                type: :array,
                items: {
                  type: :object,
                  required: %w[name path],
                  properties: { name: { type: :string }, path: { type: :string } }
                }
              },
              seo_text: { type: :string, nullable: true }
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
