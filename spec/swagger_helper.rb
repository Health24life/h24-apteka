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
              pack: { '$ref' => '#/components/schemas/goods_pack' },
              is_recipe: { type: :boolean },
              is_strict_recipe: { type: :boolean },
              trade_name: { type: :string, nullable: true },
              producer: { '$ref' => '#/components/schemas/goods_producer' },
              group: {
                type: :object,
                properties: {
                  ref: { type: :string, pattern: '^[0-9a-f]{16}$', description: 'Opaque key of the goods group' },
                  name: { type: :string, nullable: true }
                }
              }
            }
          },
          goods_pack: {
            type: :object,
            properties: {
              unit_name: { type: :string, nullable: true },
              quantity_in_pack: { type: :integer, nullable: true },
              quantity_unit_in_pack: { type: :integer, nullable: true },
              quantity_in_unit: { type: :integer, nullable: true }
            }
          },
          goods_producer: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true },
              country_code: { type: :string, nullable: true, description: 'Upper case; the country is not named' }
            }
          },
          favorite_goods: {
            type: :object,
            description: 'A SKU of «Мої товари» with the static data of its card: no prices or stock, as a price ' \
                         'belongs to a drugstore',
            required: %w[
              id slug name release_form dosage pack is_recipe is_strict_recipe trade_name producer available added_at
            ],
            properties: {
              id: { type: :integer },
              slug: { type: :string, description: 'Address of the card' },
              name: { type: :string, nullable: true },
              release_form: { type: :string, nullable: true },
              dosage: { type: :string, nullable: true },
              pack: { '$ref' => '#/components/schemas/goods_pack' },
              is_recipe: { type: :boolean },
              is_strict_recipe: { type: :boolean },
              trade_name: { type: :string, nullable: true },
              producer: { '$ref' => '#/components/schemas/goods_producer' },
              available: {
                type: :boolean,
                description: 'False while an operator hides the SKU or its group or the sync withdraws it; the ' \
                             'record stays in the list'
              },
              added_at: { type: :string, format: 'date-time' }
            }
          },
          favorite_goods_response: {
            type: :object,
            required: %w[goods],
            properties: {
              goods: {
                type: :array,
                description: 'The last added first, all of them: a list holds up to 100',
                items: { '$ref' => '#/components/schemas/favorite_goods' }
              }
            }
          },
          favorite_drugstore: {
            allOf: [
              { '$ref' => '#/components/schemas/drugstore' },
              {
                type: :object,
                required: %w[available added_at],
                properties: {
                  available: {
                    type: :boolean,
                    description: 'False while an operator hides the drugstore or the sync withdraws it; the record ' \
                                 'stays in the list'
                  },
                  added_at: { type: :string, format: 'date-time' }
                }
              }
            ]
          },
          favorite_drugstores_response: {
            type: :object,
            required: %w[drugstores],
            properties: {
              drugstores: {
                type: :array,
                description: 'The last added first, all of them: a list holds up to 100',
                items: { '$ref' => '#/components/schemas/favorite_drugstore' }
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
              },
              only_favorites: {
                type: :boolean,
                default: false,
                description: 'Only the drugstores of the user\'s «Мої аптеки», with the other filters and the sort; ' \
                             'needs a signed-in user'
              }
            }
          },
          drugstores_response: {
            type: :object,
            required: %w[drugstores],
            properties: {
              drugstores: {
                type: :array,
                description: 'The drugstores of the user\'s «Мої аптеки» first, then the rest, each part in the sort',
                items: { '$ref' => '#/components/schemas/nearby_drugstore' }
              },
              hidden_by_favorites: {
                type: :integer,
                description: 'With `only_favorites` only: drugstores that have the SKU but are not in «Мої аптеки». ' \
                             'An empty list with 0 means none around has it'
              }
            }
          },
          drugstore: {
            type: :object,
            description: 'A drugstore of the directory, with the legal entity, its EDRPOU code and the working hours',
            required: %w[
              id drugstore_legal_entity_name drugstore_legal_entity_code week_working_hours work_with_reimbursement
            ],
            properties: {
              id: { type: :integer },
              name: { type: :string, nullable: true },
              brand: { type: :object, nullable: true, required: %w[name], properties: { name: { type: :string } } },
              drugstore_legal_entity_name: { type: :string, description: 'Full name of the legal entity' },
              drugstore_legal_entity_code: {
                type: :string,
                pattern: '^[0-9]{8}([0-9]{2})?$',
                description: 'EDRPOU code of the legal entity'
              },
              address: {
                type: :object,
                nullable: true,
                required: %w[address latitude longitude],
                properties: {
                  address: { type: :string },
                  latitude: { type: :number },
                  longitude: { type: :number }
                }
              },
              phone: { type: :string, nullable: true },
              booking_available: { type: :boolean, description: 'Whether booking is open in this drugstore' },
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
                required: %w[price available_quantity favorite],
                properties: {
                  favorite: { type: :boolean, description: 'In the user\'s «Мої аптеки»; always false for a guest' },
                  distance: { type: :integer, nullable: true, description: 'Metres from the place asked about' },
                  open_now: { type: :boolean, nullable: true, description: 'Null when the provider did not tell' },
                  opens_at: {
                    type: :string,
                    format: 'date-time',
                    nullable: true,
                    description: 'The moment the drugstore next opens, today or on its next working day, in the time ' \
                                 'zone of Kyiv; null when it is open, closed within its hours, as for a break, or ' \
                                 'the hours are unknown'
                  },
                  price: {
                    type: :string,
                    pattern: '^[0-9]+\\.[0-9]{2}$',
                    description: 'Price of the SKU in the drugstore, hryvnias'
                  },
                  available_quantity: { type: :integer, description: 'Whole packs of the SKU the drugstore has' }
                }
              }
            ]
          },
          cart_item_request: {
            type: :object,
            required: %w[goods_id quantity],
            properties: {
              goods_id: { type: :integer, description: 'SKU of the catalog' },
              drugstore_id: {
                type: :integer,
                description: 'The drugstore picked from the list of drugstores with the price of the SKU, needed ' \
                             'for the first SKU. When the SKU goes to a cart it may be left out; given, it must be ' \
                             'the drugstore of the cart'
              },
              quantity: { type: :integer, minimum: 1, description: 'Whole packs, added to those already in the cart' }
            }
          },
          cart_quantity_request: {
            type: :object,
            required: %w[quantity],
            properties: { quantity: { type: :integer, minimum: 1, description: 'Whole packs' } }
          },
          cart_response: {
            type: :object,
            required: %w[cart],
            properties: { cart: { '$ref' => '#/components/schemas/cart' } }
          },
          cart: {
            type: :object,
            required: %w[drugstore prices_available items removed],
            properties: {
              token: {
                type: :string,
                description: "The owner's key to the cart, used in the path of every call on it"
              },
              drugstore: { '$ref' => '#/components/schemas/drugstore' },
              prices_available: {
                type: :boolean,
                description: 'False when the provider did not answer: the items come without prices'
              },
              items: {
                type: :array,
                items: {
                  type: :object,
                  required: %w[id quantity available],
                  properties: {
                    id: { type: :integer },
                    goods: {
                      type: :object,
                      nullable: true,
                      properties: { id: { type: :integer }, slug: { type: :string }, name: { type: :string } }
                    },
                    quantity: { type: :integer },
                    available: {
                      type: :boolean,
                      description: 'Whether the drugstore has the whole quantity now; an item it has not stays in ' \
                                   'the cart'
                    },
                    available_quantity: { type: :integer, nullable: true, description: 'Whole packs it has' },
                    price: { type: :string, nullable: true, description: 'Hryvnias; only when available' },
                    total: { type: :string, nullable: true, description: 'Hryvnias; only when available' }
                  }
                }
              },
              total: {
                type: :string,
                nullable: true,
                description: 'Hryvnias, of the available items; null without prices'
              },
              removed: {
                type: :array,
                description: 'What was taken out on the way: a SKU hidden or withdrawn, alone or with its group',
                items: {
                  type: :object,
                  properties: {
                    reason: { type: :string, enum: %w[goods_hidden goods_withdrawn] },
                    goods: { type: :object, properties: { id: { type: :integer }, name: { type: :string } } }
                  }
                }
              }
            }
          },
          booking_request: {
            type: :object,
            required: %w[goods customer personal_data_consent cf-turnstile-response],
            properties: {
              goods: {
                type: :array,
                description: 'The goods of the cart, all of them, with the prices the user saw and agreed to',
                items: {
                  type: :object,
                  required: %w[goods_id quantity price],
                  properties: {
                    goods_id: { type: :integer },
                    quantity: { type: :integer, minimum: 1 },
                    price: { type: :string, description: 'Hryvnias, as the cart showed it' }
                  }
                }
              },
              customer: {
                type: :object,
                required: %w[first_name phone_number],
                properties: {
                  first_name: { type: :string, maxLength: 100 },
                  last_name: { type: :string, maxLength: 100 },
                  middle_name: { type: :string, maxLength: 100 },
                  phone_number: { type: :string, description: 'Any Ukrainian form; kept as 380XXXXXXXXX' },
                  email: { type: :string }
                }
              },
              personal_data_consent: { type: :boolean, enum: [ true ], description: 'Checked by the server' },
              register_account: { type: :boolean, description: 'The wish to register; no account is made yet' },
              'cf-turnstile-response': { type: :string, description: 'Token of the Cloudflare Turnstile widget' }
            }
          },
          order_response: {
            type: :object,
            required: %w[order],
            properties: { order: { '$ref' => '#/components/schemas/order' } }
          },
          order: {
            type: :object,
            description: 'A sent order, as it was when it was sent',
            required: %w[token own_number state status drugstore items total],
            properties: {
              token: {
                type: :string,
                description: "The one key, the same as the cart's; also the link the booking is shared by"
              },
              own_number: { type: :string, description: 'Number of Health24' },
              customer_number: { type: :string, nullable: true, description: "The partner's number for the client" },
              state: { type: :string, enum: %w[submitted submission_failed] },
              status: {
                type: :object,
                properties: {
                  title: { type: :string, nullable: true, description: "The partner's status, translated when known" },
                  comment: { type: :string, nullable: true },
                  known: { type: :boolean },
                  updated_at: { type: :string, format: 'date-time', nullable: true }
                }
              },
              customer: {
                type: :object,
                description: "Only for the signed-in user of the order's account; not given to a guest or by the link",
                properties: {
                  first_name: { type: :string },
                  last_name: { type: :string, nullable: true },
                  middle_name: { type: :string, nullable: true },
                  phone_number: { type: :string },
                  email: { type: :string, nullable: true }
                }
              },
              drugstore: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  name: { type: :string, nullable: true },
                  address: { type: :string, nullable: true },
                  phone: { type: :string, nullable: true }
                }
              },
              items: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    goods_id: { type: :integer, nullable: true },
                    name: { type: :string },
                    quantity: { type: :integer },
                    price: { type: :string, nullable: true },
                    total: { type: :string, nullable: true }
                  }
                }
              },
              total: { type: :string }
            }
          },
          history_response: {
            type: :object,
            required: %w[orders page per_page has_more],
            properties: {
              orders: { type: :array, items: { '$ref' => '#/components/schemas/history_order' } },
              page: { type: :integer },
              per_page: { type: :integer },
              has_more: { type: :boolean, description: 'Whether there is a next page' }
            }
          },
          history_order: {
            type: :object,
            description: "A booking of the account, without the client's data and the items",
            required: %w[token own_number state status drugstore items_count total],
            properties: {
              token: { type: :string },
              own_number: { type: :string },
              customer_number: { type: :string, nullable: true },
              state: { type: :string, enum: %w[submitted submission_failed] },
              status: {
                type: :object,
                properties: {
                  title: { type: :string, nullable: true },
                  comment: { type: :string, nullable: true },
                  known: { type: :boolean },
                  updated_at: { type: :string, format: 'date-time', nullable: true }
                }
              },
              booked_at: { type: :string, format: 'date-time', description: 'The first attempt to book' },
              drugstore: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  name: { type: :string, nullable: true },
                  address: { type: :string, nullable: true }
                }
              },
              items_count: { type: :integer },
              total: { type: :string }
            }
          },
          cancellation_request: {
            type: :object,
            properties: {
              reason: {
                type: :string,
                maxLength: 255,
                description: 'Optional; without it the drugstore gets «Скасовано клієнтом»'
              }
            }
          },
          pillbox_plan_request: {
            type: :object,
            required: %w[title timezone items_attributes],
            properties: {
              title: { type: :string, maxLength: 50, description: 'Not blank once the spaces around it are cut' },
              timezone: { type: :string, example: 'Europe/Kyiv', description: 'IANA time zone of the plan' },
              start_date: {
                type: :string,
                format: :date,
                description: 'The day the courses start; today in the time zone of the plan by default, not earlier'
              },
              source_order_id: {
                type: :integer,
                description: 'A booking of the user the client filled the plan from; the booking is not changed'
              },
              items_attributes: {
                type: :array,
                minItems: 1,
                maxItems: 10,
                description: 'The medicines; their errors are keyed `items[<index>].<field>` and `items`',
                items: { '$ref' => '#/components/schemas/pillbox_plan_item_request' }
              }
            }
          },
          pillbox_plan_item_request: {
            type: :object,
            description: 'A medicine with its whole schedule; the client keeps `source` and `goods_id` consistent',
            required: %w[source every_unit times course_mode],
            properties: {
              source: { type: :string, enum: %w[order catalog manual] },
              goods_id: { type: :integer, description: 'A SKU the catalog has, shown or not' },
              name: { type: :string, maxLength: 255 },
              dosage: { type: :string, maxLength: 100 },
              position: { type: :integer, description: 'The place in the list of the request by default' },
              every_unit: { type: :string, enum: %w[day week month] },
              every_n: { type: :integer, minimum: 1, maximum: 99, default: 1, description: 'Every N units' },
              weekdays: {
                type: :array,
                items: { type: :integer, minimum: 0, maximum: 6 },
                description: 'Weekly only, 0 is Sunday; none means the weekday of the start date'
              },
              times: {
                type: :array,
                minItems: 1,
                maxItems: 6,
                items: { type: :string, pattern: '^([01]\d|2[0-3]):[0-5]\d$' },
                description: 'HH:MM in the time zone of the plan, no repeats'
              },
              reminder_mode: { type: :string, enum: %w[once until_marked], default: 'once' },
              course_mode: { type: :string, enum: %w[days until open] },
              course_days: { type: :integer, minimum: 1, maximum: 365, description: 'For days only' },
              course_end_date: {
                type: :string,
                format: :date,
                description: 'For until only: from the start date to 365 days after it'
              }
            }
          },
          pillbox_plan_response: {
            type: :object,
            required: %w[plan],
            properties: { plan: { '$ref' => '#/components/schemas/pillbox_plan' } }
          },
          pillbox_plan: {
            type: :object,
            required: %w[id title timezone status source_order_id created_at items],
            properties: {
              id: { type: :integer },
              title: { type: :string },
              timezone: { type: :string },
              status: { type: :string, enum: %w[active paused completed] },
              source_order_id: { type: :integer, nullable: true },
              created_at: { type: :string, format: 'date-time' },
              items: {
                type: :array,
                description: 'By position',
                items: { '$ref' => '#/components/schemas/pillbox_plan_item' }
              }
            }
          },
          pillbox_plan_item: {
            type: :object,
            required: %w[
              id
              source
              goods_id
              name
              dosage
              position
              every_unit
              every_n
              weekdays
              times
              reminder_mode
              course_mode
              course_start_date
              course_days
              course_end_date
            ],
            properties: {
              id: { type: :integer },
              source: { type: :string, enum: %w[order catalog manual] },
              goods_id: { type: :integer, nullable: true },
              name: { type: :string, nullable: true },
              dosage: { type: :string, nullable: true },
              position: { type: :integer },
              every_unit: { type: :string, enum: %w[day week month] },
              every_n: { type: :integer },
              weekdays: { type: :array, items: { type: :integer } },
              times: { type: :array, items: { type: :string } },
              reminder_mode: { type: :string, enum: %w[once until_marked] },
              course_mode: { type: :string, enum: %w[days until open] },
              course_start_date: { type: :string, format: :date },
              course_days: { type: :integer, nullable: true, description: 'Null for an open course' },
              course_end_date: { type: :string, format: :date, nullable: true, description: 'Null for an open course' }
            }
          },
          validation_errors: {
            type: :object,
            description: 'The errors of the model as Rails gives them: a field, or `items[<index>].<field>` for a ' \
                         'medicine by its place in the request, or `base`, with its messages',
            additionalProperties: { type: :array, items: { type: :string } }
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
                  message: { type: :string, description: 'Message in Ukrainian' },
                  details: {
                    type: :object,
                    description: 'What the front acts on, for some codes only: `available_quantity` for ' \
                                 '`quantity_exceeds_stock`, `reason` for a cart that went whole, `limit` for ' \
                                 '`favorites_limit_reached`'
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
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
