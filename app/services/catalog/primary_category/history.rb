# frozen_string_literal: true

# Leaves a record on the card of a goods group that its primary category moved: who moved it, an admin or the provider
# whose import did, and from which branch to which. The branches are kept as text, so renaming a category later leaves
# the history as it was written.
class Catalog::PrimaryCategory::History
  def self.record(group:, from:, to:, author:)
    ActiveAdmin::Comment.new(resource: group, author:, namespace: 'admin', body: body(from, to)).save!
  end

  def self.body(from, to)
    I18n.t("admin.primary_category.history.#{kind(from, to)}", from: from&.branch_name, to: to&.branch_name)
  end

  def self.kind(from, to)
    return 'assigned' unless from

    to ? 'changed' : 'cleared'
  end

  private_class_method :body, :kind
end
