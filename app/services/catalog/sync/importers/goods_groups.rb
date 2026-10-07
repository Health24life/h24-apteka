# frozen_string_literal: true

# One page of goods groups per step; the cursor is the page number.
class Catalog::Sync::Importers::GoodsGroups
  def self.first_cursor = 1

  def self.call(tracker, client, linker, cursor)
    page = client.goods_groups(page: cursor.to_i)
    saver = Catalog::Sync::Savers::GoodsGroup.new(linker, tracker)
    page.items.each { |item| tracker.guard('Catalog::Goods::Group', item[:external_id], item) { saver.call(item) } }
    tracker.update_progress('last_page' => page.last_page)
    page.last? ? nil : cursor.to_i + 1
  end

  # The next page after one that could not be read, as far as the last page is known.
  def self.skip(tracker, cursor)
    last_page = tracker.run.progress['last_page'].to_i
    cursor.to_i < last_page ? cursor.to_i + 1 : nil
  end
end
