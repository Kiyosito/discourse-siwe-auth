# frozen_string_literal: true

require "omniauth/strategies/siwe"

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :siwe
end
