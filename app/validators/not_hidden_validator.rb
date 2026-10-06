# frozen_string_literal: true

# Hidden means an administrator banned selling the record. +via+ names a parent record whose hiding counts too, for
# example the goods group of a SKU.
class NotHiddenValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :hidden) if value && hidden?(value)
  end

  private

  def hidden?(value)
    value.hidden? || (via && value.public_send(via).hidden?)
  end

  def via
    options[:via]
  end
end
