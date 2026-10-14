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
            required: %w[status location title description h1 robots breadcrumbs seo_text content],
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
              seo_text: { type: :string, nullable: true },
              content: { type: :string, nullable: true,
                         description: 'Text of a static page as HTML of the allowed tags; empty for other pages' }
            }
          },
          seo_filter_item: {
            type: :object,
            required: %w[id name slug path],
            properties: {
              id: { type: :integer },
              name: { type: :string, example: 'Вітаміни для дітей' },
              slug: { type: :string, example: 'vitaminy-dlia-ditei' },
              path: { type: :string, example: '/dobirka/vitaminy-dlia-ditei', description: 'Path of the filter page' }
            }
          },
          seo_filter_list: {
            type: :object,
            required: %w[filters],
            properties: { filters: { type: :array, items: { '$ref' => '#/components/schemas/seo_filter_item' } } }
          },
          seo_filter: {
            type: :object,
            required: %w[id name slug path category sort_order recipe_scope params applied_params],
            properties: {
              id: { type: :integer },
              name: { type: :string },
              slug: { type: :string },
              path: { type: :string },
              category: {
                type: :object, nullable: true, required: %w[id name path],
                description: 'Category the filter is shown in; empty for a filter of the home page of the section',
                properties: { id: { type: :integer }, name: { type: :string }, path: { type: :string } }
              },
              sort_order: { type: :string, enum: %w[name newest], description: 'Order of the goods' },
              recipe_scope: { type: :string, enum: %w[otc rx any],
                              description: 'Goods without a prescription only, with one only, or all' },
              params: {
                type: :object,
                description: 'Parameters of the catalog search as kept: each key with a list of ids',
                additionalProperties: { type: :array, items: { type: :integer } },
                example: { category_id: [ 12 ], form_id: [ 7, 8 ] }
              },
              applied_params: {
                type: :array,
                description: 'Badges of the page: each parameter with its Ukrainian name and the names of its values',
                items: {
                  type: :object,
                  required: %w[key name values],
                  properties: {
                    key: { type: :string, example: 'form_id' },
                    name: { type: :string, example: 'Форма випуску' },
                    values: {
                      type: :array,
                      items: {
                        type: :object, required: %w[id name],
                        properties: { id: { type: :integer }, name: { type: :string, example: 'Капсули' } }
                      }
                    }
                  }
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
