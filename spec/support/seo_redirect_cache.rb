# frozen_string_literal: true

# The redirect cache lives in Redis, which the transaction of an example does not roll back.
RSpec.configure do |config|
  config.before { Seo::Redirects::Cache.clear }
end
