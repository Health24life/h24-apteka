# frozen_string_literal: true

# Wire Tom Select (activeadmin-tom_select) into ActiveAdmin 4's OWN importmap.
#
# AA4 serves the admin panel from ActiveAdmin.importmap — a separate Importmap::Map from the app's
# config/importmap.rb — and executes a single entry module, `active_admin`. To run Tom Select's
# initializer we re-point that entry at our wrapper (app/javascript/active_admin_tom.js), which
# imports ActiveAdmin's original bundle (kept reachable here as `active_admin_core`) and then calls
# setupAutoInit. The classic activeadmin-searchable_select could not be used: it is jQuery/Select2
# and pinned to activeadmin < 4.
#
# Tom Select and its two @orchidjs sub-packages are vendored under vendor/javascript as ESM bundles
# (from jsdelivr, with the cross-package `/npm/...` imports rewritten to the bare specifiers pinned
# below) so the admin panel has no runtime CDN dependency. The matching CSS is @import-ed into the
# ActiveAdmin Tailwind build (app/assets/tailwind/active_admin.css).
#
# Drawn in an after_initialize hook, NOT at the top level: ActiveAdmin's engine draws its own
# importmap (pinning `active_admin` -> its bundle) AFTER app config initializers run, so a top-level
# `pin "active_admin"` here would be clobbered by the gem. after_initialize runs after every engine
# initializer, so our `active_admin` override is the last write and wins.
Rails.application.config.after_initialize do
  ActiveAdmin.importmap.draw do
    pin 'tom-select', to: 'tom-select.min.js', preload: true
    pin '@orchidjs/sifter', to: 'orchidjs-sifter.min.js', preload: true
    pin '@orchidjs/unicode-variants', to: 'orchidjs-unicode-variants.min.js', preload: true
    pin 'activeadmin-tom_select', to: 'activeadmin-tom_select.js', preload: true

    # Keep ActiveAdmin's own JS entry reachable, then override the `active_admin` entry with our
    # wrapper so Tom Select initializes on top of the stock ActiveAdmin bundle.
    pin 'active_admin_core', to: 'active_admin.js', preload: true
    pin 'active_admin', to: 'active_admin_tom.js', preload: true
  end
end
