# frozen_string_literal: true

# Trix for the `as: :rich_text` inputs of the admin (app/javascript/admin/rich_text.js). trix.js comes from the
# action_text-trix gem that Rails already bundles; ActionText itself is not used, the text stays plain HTML in the
# model. Drawn after initialize for the same reason as the Tom Select pins.
Rails.application.config.after_initialize do
  ActiveAdmin.importmap.draw do
    pin 'trix', to: 'trix.js', preload: true
    pin 'admin/rich_text', to: 'admin/rich_text.js', preload: true
  end
end
