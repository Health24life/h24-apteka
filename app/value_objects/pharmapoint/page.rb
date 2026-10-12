# frozen_string_literal: true

# One page of a paginated partner answer; the partner reports no total pages, only the total of items.
class Pharmapoint::Page < Data.define(:items, :page, :per_page, :total)
  def last_page = per_page.positive? ? [ (total.to_f / per_page).ceil, 1 ].max : 1

  def last? = page >= last_page
end
