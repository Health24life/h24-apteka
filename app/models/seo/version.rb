# frozen_string_literal: true

# A change of the SEO data or of a static page: what changed, on the card of which page it shows, and who made it,
# an admin or, for a change outside the admin, nobody. It stays after the record it describes is gone.
class Seo::Version < ApplicationRecord
  include PaperTrail::VersionConcern

  belongs_to :owner, polymorphic: true, optional: true
  belongs_to :author, polymorphic: true, optional: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
end
