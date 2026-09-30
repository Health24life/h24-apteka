# frozen_string_literal: true

# Checks the shape only: an unusual day text must never block an update of the drugstore from the provider.
class WeekWorkingHoursValidator < ActiveModel::EachValidator
  DAYS = 7

  def validate_each(record, attribute, value)
    return if empty_schedule?(value)
    return if seven_days?(value)

    record.errors.add(attribute, :invalid_week_working_hours)
  end

  private

  def empty_schedule?(value)
    value.is_a?(Array) && value.empty?
  end

  def seven_days?(value)
    value.is_a?(Array) && value.size == DAYS && value.all? { |day| day.nil? || day.is_a?(String) }
  end
end
