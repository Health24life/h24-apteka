# frozen_string_literal: true

# Removes the redirects past their period. Until then an old slug stays taken, so this is what frees it.
class Seo::Redirects::Cleanup
  def self.call = Seo::Redirect.expired.delete_all
end
