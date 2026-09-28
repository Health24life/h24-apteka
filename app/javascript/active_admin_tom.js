// ActiveAdmin JS entry (H24 Apteka): loads ActiveAdmin's own bundle, then upgrades the
// `.tom-select-input` selects (filters and inputs declared `as: :tom_select` across app/admin/**) into
// searchable Tom Select boxes backed by the `all_options` JSON endpoint.
//
// `active_admin` is re-pinned to THIS file in config/initializers/active_admin_tom_select.rb.
// ActiveAdmin's original entry stays reachable as `active_admin_core`; we only wrap it (rather
// than reproduce its flowbite/ujs/feature imports) so the wiring survives ActiveAdmin upgrades.
import "active_admin_core";
import { setupAutoInit } from "activeadmin-tom_select";

setupAutoInit();
