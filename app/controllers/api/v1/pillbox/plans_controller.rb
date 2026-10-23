# frozen_string_literal: true

class Api::V1::Pillbox::PlansController < ApiController
  include PillboxActions

  ITEM_FIELDS = [
    :source,
    :goods_id,
    :name,
    :dosage,
    :position,
    :every_unit,
    :every_n,
    :reminder_mode,
    :course_mode,
    :course_days,
    :course_end_date,
    { times: [], weekdays: [] }
  ].freeze

  def create
    plan = Pillbox::Plans::Create.call(user_id: current_user_id, attributes: create_params)
    if plan.persisted?
      render json: { plan: Pillbox::PlanBlueprint.render_as_hash(plan) }, status: :created
    else
      render json: plan.errors, status: :unprocessable_content
    end
  end

  def update
    plan = policy_scope(Pillbox::Plan).find(params.expect(:id))
    authorize plan

    plan = Pillbox::Plans::Update.call(plan, attributes: update_params)
    if plan.errors.any?
      render json: plan.errors, status: :unprocessable_content
    else
      render json: { plan: Pillbox::PlanBlueprint.render_as_hash(plan) }
    end
  end

  private

  def create_params
    params.permit(:title, :timezone, :start_date, :source_order_id, items_attributes: ITEM_FIELDS)
  end

  def update_params = params.permit(:title, items_attributes: [ :id, :discard, *ITEM_FIELDS ])
end
