# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt certificate otp ssn cvv cvc
]
# What a user searches for may tell of their health; the provider request log keeps it, the application log does not.
Rails.application.config.filter_parameters += %i[queries]
