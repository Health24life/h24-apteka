# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Pillbox plan updates' do
  let(:user_id) { create(:h24_core_user).id }
  let(:Authorization) { "Bearer #{generate_jwt_token(nameid: user_id)}" }
  let(:plan) do
    create(
      :pillbox_plan,
      user_id:,
      items: [
        build(:pillbox_plan_item, plan: nil, name: 'A', position: 0),
        build(:pillbox_plan_item, plan: nil, name: 'B', position: 1)
      ]
    )
  end
  let(:id) { plan.id }
  let(:body) do
    {
      title: 'Нова назва',
      items_attributes: [
        { id: first.id, times: %w[09:00 21:00] },
        { id: second.id, discard: true },
        { source: 'manual', name: 'C', every_unit: 'day', times: %w[12:00], course_mode: 'open' }
      ]
    }
  end

  def first = plan.items.first

  def second = plan.items.second

  def error_code = response.parsed_body.dig('error', 'code')

  def errors = response.parsed_body

  path '/api/v1/pillbox/plans/{id}' do
    patch 'Changes a plan of the signed-in user at once' do
      tags 'Pillbox'
      description 'The title and the medicines in one save: with `id` a medicine changes, with `id` and ' \
                  '`discard: true` it is taken out of the plan, without `id` it is added and starts today. A change ' \
                  'of the schedule or the course works from now; the start of the course and the intakes stay. ' \
                  'Only an active or a paused plan changes. Invalid data is answered with the errors of every field ' \
                  'at once and nothing changes.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, required: true, schema: { type: :integer }, description: 'The plan'
      parameter name: :Authorization,
                in: :header,
                required: true,
                schema: { type: :string },
                description: 'Bearer token of the signed-in user'
      parameter name: :body,
                in: :body,
                required: true,
                schema: { '$ref' => '#/components/schemas/pillbox_plan_update_request' }

      response '200', 'the plan with the changes: a medicine changed, one taken out, one added' do
        schema '$ref' => '#/components/schemas/pillbox_plan_response'

        run_test! do
          expect(response.parsed_body['plan'].then { [ it['title'], it['items'].map { |item| item['name'] } ] })
            .to eq([ 'Нова назва', %w[A C] ])
        end
      end

      response '401', 'unauthorized: no session' do
        schema '$ref' => '#/components/schemas/error'

        let(:Authorization) { nil }

        run_test! { expect(error_code).to eq('unauthorized') }
      end

      response '403', 'forbidden: the plan is completed' do
        schema '$ref' => '#/components/schemas/error'

        before { plan.update!(status: 'completed') }

        run_test! { expect(error_code).to eq('forbidden') }
      end

      response '404', 'pillbox_plan_not_found: a plan of someone else, or no such plan' do
        schema '$ref' => '#/components/schemas/error'

        let(:id) { create(:pillbox_plan).id }

        run_test! { expect(error_code).to eq('pillbox_plan_not_found') }
      end

      response '404', 'pillbox_plan_item_not_found: a medicine already taken out, or of another plan' do
        schema '$ref' => '#/components/schemas/error'

        let(:body) { { items_attributes: [ { id: create(:pillbox_plan_item).id, dosage: '1 капсула' } ] } }

        run_test! { expect(error_code).to eq('pillbox_plan_item_not_found') }
      end

      response '422', 'the errors of every field at once, a medicine named by its place in items_attributes' do
        schema '$ref' => '#/components/schemas/validation_errors'

        let(:body) { { items_attributes: [ { id: second.id, dosage: 'x' }, { id: first.id, times: [] } ] } }

        run_test! { expect(errors.keys).to eq([ 'items[1].times' ]) }
      end

      response '422', 'items: the last medicine cannot be taken out' do
        schema '$ref' => '#/components/schemas/validation_errors'

        let(:body) { { items_attributes: [ { id: first.id, discard: true }, { id: second.id, discard: true } ] } }

        run_test! { expect(errors.keys).to eq([ 'items' ]) }
      end

      response '422', 'items[0].course_days: a changed course may not end before today' do
        schema '$ref' => '#/components/schemas/validation_errors'

        before { first.update!(course_start_date: 10.days.ago.to_date, course_days: 14) }

        let(:body) { { items_attributes: [ { id: first.id, course_days: 5 } ] } }

        run_test! { expect(errors.keys).to eq([ 'items[0].course_days' ]) }
      end
    end
  end

  describe 'what is kept' do
    def patch_plan
      patch "/api/v1/pillbox/plans/#{id}",
            params: body.to_json,
            headers: { 'Authorization' => self.Authorization, 'Content-Type' => 'application/json' }
    end

    it 'keeps the intakes of a medicine taken out and the start of a changed one', :aggregate_failures do
      start = first.course_start_date
      intake = create(:pillbox_intake, plan_item: second, plan:)

      patch_plan

      expect(Pillbox::Intake.exists?(intake.id)).to be(true)
      expect(first.reload).to have_attributes(course_start_date: start, schedule_version: 2)
    end

    it 'changes nothing of a completed plan', :aggregate_failures do
      plan.update!(status: 'completed')

      patch_plan

      expect(response).to have_http_status(:forbidden)
      expect(plan.reload.title).to eq('Застуда')
    end
  end
end
