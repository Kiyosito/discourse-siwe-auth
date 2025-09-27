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
          Rails.logger.info("[SIWE OmniAuth] Starting verification")
          Rails.logger.info("[SIWE OmniAuth] Raw message length: #{raw_message&.length}")
          Rails.logger.info("[SIWE OmniAuth] Signature: #{signature&.slice(0,10)}...")
          Rails.logger.info("[SIWE OmniAuth] Wallet param: #{wallet_param}")
          Rails.logger.info("[SIWE OmniAuth] Nonce param: #{request.params['nonce']}")
          Rails.logger.info("[SIWE OmniAuth] Session nonce: #{session['siwe_nonce']}")

          # Normalize Windows CRLF to LF to satisfy siwe gem regex expectations
          normalized_message = raw_message.to_s.gsub("\r\n", "\n")
          Rails.logger.info("[SIWE OmniAuth] Normalized message: #{normalized_message.inspect}")

          siwe_msg = ::Siwe::Message.from_message(normalized_message)
          Rails.logger.info("[SIWE OmniAuth] Parsed SIWE message: address=#{siwe_msg.address}, domain=#{siwe_msg.domain}, nonce=#{siwe_msg.nonce}")

          validation_nonce = request.params["nonce"].presence || session["siwe_nonce"]
          Rails.logger.info("[SIWE OmniAuth] Using nonce: #{validation_nonce}")

          # Verify signature with nonce and domain (siwe 1.1.2 requires both)
          siwe_msg.verify(signature: signature, domain: siwe_msg.domain, nonce: validation_nonce)
          Rails.logger.info("[SIWE OmniAuth] Signature verified successfully")

          eth_address = (wallet_param.presence || siwe_msg.address).to_s.downcase
          Rails.logger.info("[SIWE OmniAuth] Final eth_address: #{eth_address}")

          self.env["omniauth.auth"] = {
            "provider" => "siwe",
            "uid"      => eth_address,
            "info"     => { "eth_address" => eth_address }
          }

          Rails.logger.info("[SIWE OmniAuth] Auth hash created, calling app")
          call_app!
        rescue => e
          Rails.logger.error("[SIWE OmniAuth] Verification failed: #{e.class}: #{e.message}")
          Rails.logger.error("[SIWE OmniAuth] Backtrace: #{e.backtrace.first(5).join("\n")}")
          fail!(:invalid_signature, e)
        end
      end
    end
  end
end
