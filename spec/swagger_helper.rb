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
          search_request: {
            type: :object,
            required: %w[queries],
            properties: {
              queries: {
                type: :array,
                minItems: 1,
                description: 'Search queries; this release takes exactly one',
                items: {
                  type: :object,
                  required: %w[text],
                  properties: {
                    text: {
                      type: :string,
                      minLength: 3,
                      maxLength: 100,
                      description: 'Counted after squeezing spaces'
                    },
                    page: { type: :integer, minimum: 1, maximum: 50, default: 1, description: 'Page of goods groups' },
                    location: {
                      type: :object,
                      description: 'Where to look. Without the coordinates the configured point is taken, without ' \
                                   'the radius the configured one; the coordinates are rounded to about a kilometre',
                      properties: {
                        latitude: { type: :number, minimum: -90, maximum: 90, description: 'With longitude only' },
                        longitude: { type: :number, minimum: -180, maximum: 180, description: 'With latitude only' },
                        radius: { type: :integer, minimum: 1, description: 'Metres, up to the configured maximum' }
                      }
                    }
                  }
                }
              }
            }
          },
          search_response: {
            type: :object,
            required: %w[results],
            properties: {
              results: {
                type: :array,
                description: 'A result per query, in the order of the queries',
                items: { '$ref' => '#/components/schemas/search_result' }
              }
            }
          },
          search_result: {
            type: :object,
            required: %w[query status page per_page total_groups has_more goods],
            properties: {
              query: { type: :string },
              status: {
                type: :string,
                enum: %w[ok partial unavailable],
                description: '`partial`: the list may lack goods, as some sources did not answer; `unavailable`: no ' \
                             'source answered, while another query of the request was answered'
              },
              page: { type: :integer },
              per_page: { type: :integer, description: 'Goods groups per page, not rows' },
              total_groups: { type: :integer, description: 'Goods groups the providers have for the text' },
              has_more: { type: :boolean },
              goods: { type: :array, items: { '$ref' => '#/components/schemas/search_goods' } }
            }
          },
          search_goods: {
            type: :object,
            description: 'A release form (SKU) with the static data of its card: no prices, stock or images, and ' \
                         'nothing of the provider it came from',
            required: %w[
              ref
              ready
              id
              slug
              name
              release_form
              dosage
              pack
              is_recipe
              is_strict_recipe
              trade_name
              producer
              group
            ],
            properties: {
              ref: {
                type: :string,
                pattern: '^[0-9a-f]{16}$',
                description: 'Opaque key of the row, the same in every search; tells nothing of where the goods ' \
                             'come from'
              },
              ready: {
                type: :boolean,
                description: 'Whether the catalog shows the SKU. A row that is not ready has no card yet: it cannot ' \
                             'be opened or put in the cart, and a later search lists it as ready once it is saved'
              },
              id: { type: :integer, nullable: true },
              slug: { type: :string, nullable: true, description: 'Address of the card; null when not ready' },
              name: { type: :string, nullable: true },
              release_form: { type: :string, nullable: true },
              dosage: { type: :string, nullable: true },
              pack: {
                type: :object,
                properties: {
                  unit_name: { type: :string, nullable: true },
                  quantity_in_pack: { type: :integer, nullable: true },
                  quantity_unit_in_pack: { type: :integer, nullable: true },
                  quantity_in_unit: { type: :integer, nullable: true }
                }
              },
              is_recipe: { type: :boolean },
              is_strict_recipe: { type: :boolean },
              trade_name: { type: :string, nullable: true },
              producer: {
                type: :object,
                properties: {
                  name: { type: :string, nullable: true },
                  country_code: { type: :string, nullable: true, description: 'Upper case; the country is not named' }
                }
              },
              group: {
                type: :object,
                properties: {
                  ref: { type: :string, pattern: '^[0-9a-f]{16}$', description: 'Opaque key of the goods group' },
                  name: { type: :string, nullable: true }
                }
              }
            }
          },
          drugstores_request: {
            type: :object,
            properties: {
              location: {
                type: :object,
                description: 'Where to look, as in the search: without the coordinates the configured point is ' \
                             'taken, without the radius the configured one; the coordinates are rounded to about a ' \
                             'kilometre',
                properties: {
                  latitude: { type: :number, minimum: -90, maximum: 90, description: 'With longitude only' },
                  longitude: { type: :number, minimum: -180, maximum: 180, description: 'With latitude only' },
                  radius: { type: :integer, minimum: 1, description: 'Metres, up to the configured maximum' }
                }
              },
              sort: {
                type: :string,
                enum: %w[price distance],
                default: 'price',
                description: 'The cheapest or the nearest first'
              },
              work_with_reimbursement: {
                type: :boolean,
                description: 'Only drugstores of the program «Доступні ліки»'
              }
            }
          },
          drugstores_response: {
            type: :object,
            required: %w[drugstores],
            properties: {
              drugstores: { type: :array, items: { '$ref' => '#/components/schemas/nearby_drugstore' } }
            }
          },
          drugstore: {
            type: :object,
            description: 'A drugstore of the directory, with the legal entity, its EDRPOU code and the working hours',
            required: %w[id legal_entity week_working_hours work_with_reimbursement],
            properties: {
              id: { type: :integer },
              name: { type: :string, nullable: true },
              brand: { type: :object, nullable: true, properties: { name: { type: :string } } },
              legal_entity: {
                type: :object,
                required: %w[name code],
                properties: {
                  name: { type: :string, description: 'Full name of the legal entity' },
                  code: { type: :string, pattern: '^[0-9]{8}([0-9]{2})?$', description: 'EDRPOU code' }
                }
              },
              address: { type: :string, nullable: true },
              latitude: { type: :number, nullable: true },
              longitude: { type: :number, nullable: true },
              phone: { type: :string, nullable: true },
              week_working_hours: {
                type: :array,
                description: 'Seven days from Monday, `HH:MM-HH:MM` or null for a day off; empty when unknown',
                items: { type: :string, nullable: true }
              },
              work_with_reimbursement: { type: :boolean, description: 'Takes part in the program «Доступні ліки»' }
            }
          },
          nearby_drugstore: {
            allOf: [
              { '$ref' => '#/components/schemas/drugstore' },
              {
                type: :object,
                required: %w[goods],
                properties: {
                  distance: { type: :integer, nullable: true, description: 'Metres from the place asked about' },
                  open_now: { type: :boolean, nullable: true, description: 'Null when the provider did not tell' },
                  opens_at: {
                    type: :string,
                    nullable: true,
                    description: '`HH:MM` the drugstore next opens at, today or on its next working day; null when ' \
                                 'it is open or the hours are unknown'
                  },
                  goods: {
                    type: :object,
                    required: %w[price available_quantity],
                    properties: {
                      price: {
                        type: :string,
                        pattern: '^[0-9]+\\.[0-9]{2}$',
                        description: 'Price in the drugstore, hryvnias'
                      },
                      available_quantity: { type: :integer, description: 'Whole packs the drugstore has' }
                    }
                  }
                }
              }
            ]
          },
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
