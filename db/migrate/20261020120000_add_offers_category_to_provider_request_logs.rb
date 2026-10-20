class AddOffersCategoryToProviderRequestLogs < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :provider_request_logs, name: 'provider_request_logs_category_check'
    add_check_constraint :provider_request_logs,
                         "category IN ('booking', 'search', 'offers', 'refresh', 'other')",
                         name: 'provider_request_logs_category_check'
  end

  def down
    remove_check_constraint :provider_request_logs, name: 'provider_request_logs_category_check'
    add_check_constraint :provider_request_logs,
                         "category IN ('booking', 'search', 'refresh', 'other')",
                         name: 'provider_request_logs_category_check'
  end
end
