# frozen_string_literal: true

require "siwe"

module DiscourseSiwe
  class AuthController < ::ApplicationController
    skip_before_action :redirect_to_login_if_required
    requires_plugin ::DiscourseSiwe

    def index
      render plain: "SIWE AuthController up"
    end

    def message
      eth_account = params[:eth_account]
      chain_id    = params[:chain_id]

      Rails.logger.info("[SIWE] Incoming raw address=#{eth_account.inspect}, chain_id=#{chain_id.inspect}")

      begin
        # Normaliza para EIP-55 checksum
        eth_account = Eth::Address.new(eth_account).checksummed
        Rails.logger.info("[SIWE] Checksummed address=#{eth_account}")
      rescue => e
        Rails.logger.error("[SIWE] Invalid ETH address received: #{eth_account.inspect} (#{e.class}: #{e.message})")
        return render json: { error: "invalid_address", detail: e.message }, status: 422
      end

      domain = Discourse.base_url
      domain.slice!("#{Discourse.base_protocol}://")

      message = Siwe::Message.new(
        domain,
        eth_account,
        Discourse.base_url,
        "1",
        issued_at: Time.now.utc.iso8601,
        statement: SiteSetting.siwe_statement.presence || "Sign in with Ethereum",
        nonce: Siwe::Util.generate_nonce,
        chain_id: chain_id,
      )

      session[:nonce] = message.nonce

      Rails.logger.info("[SIWE] Generated message with nonce=#{message.nonce}")

      render json: { message: message.prepare_message }
    end

    def callback
      Rails.logger.info("[SIWE] Callback params=#{params.inspect}")

      message   = params[:message]
      signature = params[:signature]

      unless message && signature
        Rails.logger.error("[SIWE] Missing SIWE params")
        return render json: { error: "missing_params" }, status: 400
      end

      begin
        siwe_msg = Siwe::Message.from_json(message)
        Rails.logger.info("[SIWE] Parsed SIWE message for address=#{siwe_msg.address}")

        siwe_msg.validate(signature)
        Rails.logger.info("[SIWE] ✅ SIWE signature valid")

        # TODO: integrate with Discourse user (find or create by eth_address)

        render json: { success: true, address: siwe_msg.address }
      rescue => e
        Rails.logger.error("[SIWE] ❌ Validation failed (#{e.class}): #{e.message}")
        render json: { error: "validation_failed", detail: e.message }, status: 401
      end
    end
  end
end
