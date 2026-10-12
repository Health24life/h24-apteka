# frozen_string_literal: true

# Hides a record from the storefront or brings it back at an operator's request, and leaves a comment on the record
# saying who did it and why. Hiding needs a reason; bringing back takes one if given.
class Catalog::Visibility::Changer
  def self.call(record:, hidden:, reason:, admin:)
    reason = reason.to_s.strip
    return :reason_required if hidden && reason.empty?
    return :unchanged if record.hidden == hidden

    record.update!(hidden:)
    comment(record, admin, hidden ? 'hidden' : 'shown', reason)
    :changed
  end

  def self.comment(record, admin, action, reason)
    key = reason.empty? ? action : "#{action}_with_reason"
    ActiveAdmin::Comment.new(resource: record, author: admin, namespace: 'admin',
                             body: I18n.t("admin.visibility.#{key}", reason:)).save!
  end

  private_class_method :comment
end
