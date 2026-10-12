# frozen_string_literal: true

# A disabled record may come back, so use this on create only: records that already exist stay as they are.
class EnabledValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :disabled) if value && !value.active?
  end
end
