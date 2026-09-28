# frozen_string_literal: true

module JwtHelper
  def generate_jwt_token(claims = {})
    payload = { exp: 5.minutes.from_now.to_i }.merge(claims)
    JWT.encode(payload, ENV.fetch('SECRET_JWT_TOKEN'))
  end
end
