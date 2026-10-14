# frozen_string_literal: true

# A column or row title of the admin with a question mark that explains it on hover.
module AdminHintsHelper
  def column_hint(title, hint) = render('admin/column_hint', title:, hint:)
end
