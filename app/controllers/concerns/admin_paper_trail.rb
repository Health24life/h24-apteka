# frozen_string_literal: true

# The author of a change made in the admin. Outside the admin nothing is written from a request, so the other
# controllers name no author and never resolve a session for it.
module AdminPaperTrail
  extend ActiveSupport::Concern

  private

  def user_for_paper_trail = current_admin_user&.id

  def info_for_paper_trail = { author: current_admin_user }
end
