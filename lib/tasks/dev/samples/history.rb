# frozen_string_literal: true

# The history of the catalog cards: records an operator hid and brought back, and a primary category an editor chose.
module DevSamples::History
  module_function

  def call(admins)
    return if ActiveAdmin::Comment.count >= 10

    hide_groups(admins.cycle)
    Catalog::Drugstore.where(hidden: false).order(:id).limit(3).each { hide(it, admins.last) }
    primary(admins.second)
  end

  def hide_groups(authors)
    Catalog::Goods::Group.order(:id).limit(12).each_slice(3).map(&:first).each { hide(it, authors.next) }
  end

  # Hides a record, and brings every other one back, so the cards show both kinds of entries.
  def hide(record, admin)
    changer = Catalog::Visibility::Changer
    changer.call(record:, hidden: true, reason: 'Перевірка інструкції', admin:)
    changer.call(record:, hidden: false, reason: 'Інструкцію виправлено', admin:) if record.id.even?
  end

  def primary(admin)
    Catalog::Goods::Group.joins(:goods_group_categories).group(:id).having('count(*) > 1').limit(5).each do |group|
      other = group.goods_group_categories.find_by(is_primary: false) or next
      Catalog::PrimaryCategory::Changer.call(group:, category_id: other.category_id, admin:)
    end
  end
end
