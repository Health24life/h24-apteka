# frozen_string_literal: true

# Every API call may reach the partner, whose request limit is shared by all clients, so one client is throttled
# before it can spend it for everyone. Counters live in Rails.cache, shared across Puma workers. Clients behind one NAT
# share an address, so the limit is set with that in mind.
Rails.application.config.x.api_throttle = ActiveSupport::OrderedOptions[
  limit: Integer(ENV.fetch('API_THROTTLE_LIMIT', 120)),
  period: Integer(ENV.fetch('API_THROTTLE_PERIOD', 60))
]

Rack::Attack.throttle(
  'api/ip',
  limit: ->(_request) { Rails.application.config.x.api_throttle.limit },
  period: ->(_request) { Rails.application.config.x.api_throttle.period }
) do |request|
  request.ip if request.path.start_with?('/api/')
end

# Answers in the error format of ApiController, telling the client when its window opens again.
Rack::Attack.throttled_responder = lambda do |request|
  match = request.env['rack.attack.match_data']
  retry_after = match[:period] - (match[:epoch_time] % match[:period])
  message = I18n.t('api_controller.errors.too_many_requests', locale: :uk)
  body = { error: { code: 'too_many_requests', message: } }.to_json
  [ 429, { 'content-type' => 'application/json', 'retry-after' => retry_after.to_s }, [ body ] ]
end
