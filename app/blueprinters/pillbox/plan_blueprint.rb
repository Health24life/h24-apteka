# frozen_string_literal: true

class Pillbox::PlanBlueprint < Blueprinter::Base
  identifier :id

  fields :title, :timezone, :status, :source_order_id, :created_at

  association(:items, blueprint: Pillbox::PlanItemBlueprint) { |plan| plan.items.sort_by(&:position) }
end
