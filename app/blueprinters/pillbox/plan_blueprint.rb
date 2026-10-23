# frozen_string_literal: true

class Pillbox::PlanBlueprint < Blueprinter::Base
  identifier :id

  fields :title, :timezone, :status, :source_order_id, :created_at

  # A plan just created keeps its items in the order of the request.
  association(:items, blueprint: Pillbox::PlanItemBlueprint) { |plan| plan.items.sort_by(&:position) }
end
