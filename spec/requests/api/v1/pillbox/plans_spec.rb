# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Pillbox plans' do
  let(:user_id) { create(:h24_core_user).id }
  let(:Authorization) { "Bearer #{generate_jwt_token(nameid: user_id)}" }
  let(:items) { [ medicine(name: 'Нурофен', goods_id: create(:catalog_goods).id, source: 'catalog'), medicine ] }
  let(:body) { { title: 'Застуда', timezone: 'Europe/Kyiv', items_attributes: items } }

  def medicine(**attrs)
    {
      source: 'manual',
      name: 'Вітамін D',
      dosage: '2 краплі',
      every_unit: 'week',
      every_n: 2,
      weekdays: [ 1, 3 ],
      times: %w[20:00 08:00],
      reminder_mode: 'until_marked',
      course_mode: 'days',
      course_days: 14
    }.merge(attrs)
  end

  def errors = response.parsed_body

  def shown_items
    response.parsed_body.dig('plan', 'items').map { it.slice('name', 'position', 'times', 'weekdays', 'course_days') }
  end

  path '/api/v1/pillbox/plans' do
    post 'Creates a plan of taking medicines of the signed-in user' do
      tags 'Pillbox'
      description 'A named plan of 1 to 10 medicines, each with its whole schedule and course: the client sends the ' \
                  'same schedule in every item when the user wants one for all. The courses start on `start_date`, ' \
                  'today in the time zone of the plan by default. A user keeps up to 5 active and paused plans. ' \
                  'Invalid data is answered with the errors of every field at once and nothing is kept.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :Authorization,
                in: :header,
                required: true,
                schema: { type: :string },
                description: 'Bearer token of the signed-in user'
      parameter name: :body,
                in: :body,
                required: true,
                schema: { '$ref' => '#/components/schemas/pillbox_plan_request' }

      response '201', 'the plan, active, with its medicines in their order' do
        schema '$ref' => '#/components/schemas/pillbox_plan_response'

        run_test! do
          expect(shown_items).to eq(
            [
              {
                'name' => 'Нурофен',
                'position' => 0,
                'times' => %w[08:00 20:00],
                'weekdays' => [ 1, 3 ],
                'course_days' => 14
              },
              {
                'name' => 'Вітамін D',
                'position' => 1,
                'times' => %w[08:00 20:00],
                'weekdays' => [ 1, 3 ],
                'course_days' => 14
              }
            ]
          )
        end
      end

      response '201', 'the owner and the status come from the server, whatever the body says' do
        schema '$ref' => '#/components/schemas/pillbox_plan_response'

        let(:body) { super().merge(user_id: create(:h24_core_user).id, status: 'completed', same_schedule: true) }

        run_test! do
          expect(Pillbox::Plan.sole).to have_attributes(user_id:, status: 'active')
        end
      end

      response '401', 'unauthorized: no session, as a plan belongs to an account' do
        schema '$ref' => '#/components/schemas/error'

        let(:Authorization) { nil }

        run_test! { expect(response.parsed_body.dig('error', 'code')).to eq('unauthorized') }
      end

      response '422', 'the errors of every field at once, an item named by its place; nothing is kept' do
        schema '$ref' => '#/components/schemas/validation_errors'

        let(:body) do
 { title: '', timezone: 'Europe/Kyiv', items_attributes: [ medicine, medicine(times: %w[01:00] * 7) ] }
        end

        run_test! { expect(errors.keys).to contain_exactly('title', 'items[1].times') }
      end

      response '422', 'base: the user keeps 5 active and paused plans already' do
        schema '$ref' => '#/components/schemas/validation_errors'

        before { create_list(:pillbox_plan, 5, user_id:) }

        run_test! { expect(errors.keys).to eq([ 'base' ]) }
      end

      response '422', 'items: more than 10 medicines' do
        schema '$ref' => '#/components/schemas/validation_errors'

        let(:items) { Array.new(11) { medicine } }

        run_test! { expect(errors.keys).to eq([ 'items' ]) }
      end

      response '422', 'source_order_id: not a booking of the user' do
        schema '$ref' => '#/components/schemas/validation_errors'

        let(:body) { super().merge(source_order_id: create(:order, :sent, user_id: create(:h24_core_user).id).id) }

        run_test! { expect(errors.keys).to eq([ 'source_order_id' ]) }
      end

      response '422', 'items[0].goods_id: no such SKU in the catalog' do
        schema '$ref' => '#/components/schemas/validation_errors'

        let(:items) { [ medicine(goods_id: 0) ] }

        run_test! { expect(errors.keys).to eq([ 'items[0].goods_id' ]) }
      end
    end
  end

  describe 'what is kept' do
    def post_plan(headers: { 'Authorization' => self.Authorization })
      post '/api/v1/pillbox/plans', params: body.to_json, headers: headers.merge('Content-Type' => 'application/json')
    end

    it 'keeps an active plan of the user of the session', :aggregate_failures do
      post_plan

      plan = Pillbox::Plan.find(response.parsed_body.dig('plan', 'id'))
      expect(plan).to have_attributes(user_id:, status: 'active', title: 'Застуда', timezone: 'Europe/Kyiv')
      expect(plan.items.count).to eq(2)
    end

    it 'keeps nothing for a guest', :aggregate_failures do
      post_plan(headers: {})

      expect(response).to have_http_status(:unauthorized)
      expect(Pillbox::Plan.count).to eq(0)
    end

    it 'keeps nothing when one item is invalid', :aggregate_failures do
      body[:items_attributes] << medicine(times: [])

      post_plan

      expect(response).to have_http_status(:unprocessable_content)
      expect([ Pillbox::Plan.count, Pillbox::PlanItem.count ]).to eq([ 0, 0 ])
    end
  end
end
