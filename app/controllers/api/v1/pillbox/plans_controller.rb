# frozen_string_literal: true

class Api::V1::Pillbox::PlansController < ApiController
  before_action :no_store
  before_action :require_user

  def create
    plan = Pillbox::Plans::Create.call(user_id: current_user_id, attributes: plan_params)
    return render json: plan.errors, status: :unprocessable_content unless plan.persisted?

    render json: { plan: Pillbox::PlanBlueprint.render_as_hash(plan) }, status: :created
  end

  private

  def require_user
    render_error(:unauthorized, status: :unauthorized) unless current_user_id
  end

  def plan_params
    params.permit(
      :title,
      :timezone,
      :start_date,
      :source_order_id,
      items_attributes: [
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
      ]
    )
  end
end
