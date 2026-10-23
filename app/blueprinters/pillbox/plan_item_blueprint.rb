# frozen_string_literal: true

class Pillbox::PlanItemBlueprint < Blueprinter::Base
  identifier :id

  fields :source,
         :goods_id,
         :name,
         :dosage,
         :position,
         :every_unit,
         :every_n,
         :weekdays,
         :times,
         :reminder_mode,
         :course_mode,
         :course_start_date,
         :course_days,
         :course_end_date
end
