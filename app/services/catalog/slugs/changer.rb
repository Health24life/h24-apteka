# frozen_string_literal: true

# An explicit change of the slug of a page, made in two steps: the check runs the record's own rules on the new slug
# without saving, so the admin can show the new address before anything moves; the change saves it, and the record
# leaves a redirect from the old slug. Spaces around the slug are dropped; anything else is the record's to judge.
class Catalog::Slugs::Changer
  class Result < Data.define(:status, :errors)
    def ok? = status != :invalid
  end

  def self.check(record:, slug:)
    new_slug = slug.to_s.strip
    return Result.new(status: :unchanged, errors: []) if new_slug == record.slug

    record.slug = new_slug
    record.valid?
    errors = record.errors.full_messages_for(:slug)
    record.restore_attributes(%w[slug])
    Result.new(status: errors.empty? ? :valid : :invalid, errors:)
  end

  def self.call(record:, slug:)
    checked = check(record:, slug:)
    return checked unless checked.status == :valid

    record.update(slug: slug.to_s.strip) ? Result.new(status: :changed, errors: []) : invalid(record)
  end

  def self.invalid(record) = Result.new(status: :invalid, errors: record.errors.full_messages_for(:slug))

  private_class_method :invalid
end
