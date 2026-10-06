# frozen_string_literal: true

# The value must not repeat among the other records of the same parent, which the +among+ lambda returns for the
# validated record. They are compared in memory: a parent that is saved for the first time has no id yet, so a
# database uniqueness check would let a repeat in.
class NotRepeatedValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.nil?

    repeated = others(record).any? { |other| other.public_send(attribute) == value }
    record.errors.add(attribute, :repeated) if repeated
  end

  private

  def others(record)
    options.fetch(:among).call(record).reject { |other| same?(other, record) }
  end

  def same?(other, record)
    other.equal?(record) || (record.persisted? && other.id == record.id)
  end
end
