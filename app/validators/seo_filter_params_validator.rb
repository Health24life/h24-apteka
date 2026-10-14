# frozen_string_literal: true

# The parameters of the catalog search an SEO filter keeps: an object whose keys are search parameters the filter
# knows, each with a list of ids of records that exist. The ids have no foreign key, so they are checked here.
class SeoFilterParamsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return record.errors.add(attribute, :not_an_object) unless value.is_a?(Hash)

    value.each do |param, ids|
      error = error_of(param, ids)
      record.errors.add(attribute, error, param:) if error
    end
  end

  private

  def error_of(param, ids)
    model = Seo::Filter::PARAMS[param] or return :unknown_param
    return :invalid_param_values unless ids?(ids)

    :missing_param_values if model.where(id: ids).count < ids.size
  end

  def ids?(ids)
    ids.is_a?(Array) && ids.any? && ids.all? { it.is_a?(Integer) && it.positive? } && ids.uniq.size == ids.size
  end
end
