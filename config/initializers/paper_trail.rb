# frozen_string_literal: true

# A version written from the admin names the admin who made the change; see AdminPaperTrail.
Rails.application.config.to_prepare do
  ActiveAdmin::BaseController.include(AdminPaperTrail)
end
