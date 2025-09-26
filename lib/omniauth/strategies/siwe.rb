# frozen_string_literal: true

require "omniauth"
require "siwe"

module OmniAuth
  module Strategies
    class Siwe
      include OmniAuth::Strategy

      option :name, "siwe"

      # 1. Generate SIWE message
      def request_phase
        # Redirect the core login button directly to our public Ember route
        return redirect("/discourse-siwe/auth")
      end

      # 2. Validate signature + extract wallet address
      def callback_phase
        # support both native omniauth names and our frontend names (eth_*)
        signature   = request.params["signature"] || request.params["eth_signature"]
        raw_message = request.params["message"]   || request.params["eth_message"]
        wallet_param = request.params["address"]  || request.params["eth_account"]

        return fail!(:missing_params, StandardError.new("Missing signature or message")) if signature.blank? || raw_message.blank?

        begin
          siwe_msg = ::Siwe::Message.from_message(raw_message)
          siwe_msg.validate(signature, nonce: session["siwe_nonce"])

          eth_address = (wallet_param.presence || siwe_msg.address).to_s.downcase

          self.env["omniauth.auth"] = {
            "provider" => "siwe",
            "uid"      => eth_address,
            "info"     => { "eth_address" => eth_address }
          }

          call_app!
        rescue => e
          fail!(:invalid_signature, e)
        end
      end
    end
  end
end
