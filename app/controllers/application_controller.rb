# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include H24Auth::SessionContext

  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  # PaperTrail would otherwise resolve the H24Auth session of every request just to name the author of a version.
  def user_for_paper_trail = nil
end
