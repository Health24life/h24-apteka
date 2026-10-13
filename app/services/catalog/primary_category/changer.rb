# frozen_string_literal: true

# Makes one of the categories the provider gave a goods group its primary one at an editor's request, and leaves a
# record of it on the card. The old mark comes off before the new one goes on, without a transaction around them:
# the index allowing one primary per group is checked row by row, so a single update over both rows trips on its own
# halfway state. An import may mark a primary in between, as it does for a group without one; then the editor's mark
# is refused and the editor sees the group as the import left it.
class Catalog::PrimaryCategory::Changer
  def self.call(group:, category_id:, admin:)
    link = group.goods_group_categories.find_by(category_id:)
    return :not_in_group unless link
    return :unchanged if link.is_primary

    previous = group.goods_group_categories.find_by(is_primary: true)
    previous&.update!(is_primary: false)
    return :conflict unless mark(link)

    group.touch # rubocop:disable Rails/SkipsModelValidations
    Catalog::PrimaryCategory::History.record(group:, from: previous&.category, to: link.category, author: admin)
    :changed
  end

  def self.mark(link)
    link.update!(is_primary: true)
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    false
  end

  private_class_method :mark
end
