# frozen_string_literal: true
require 'siwe'
require 'eth'

module DiscourseSiwe
  class AuthController < ::ApplicationController
    skip_before_action :redirect_to_login_if_required

    # Step 1: frontend asks for message to sign
    def message
      eth_account = params[:eth_account]
      Rails.logger.info("[SIWE] /message called with eth_account=#{eth_account.inspect}, chain_id=#{params[:chain_id].inspect}")

      begin
        eth_account = Eth::Address.new(eth_account).checksummed
        Rails.logger.info("[SIWE] checksummed address=#{eth_account}")
      rescue => e
        Rails.logger.warn("[SIWE] invalid address received: #{eth_account} (error: #{e.class}: #{e.message})")
        render json: { error: "Invalid Ethereum address" }, status: 422 and return
      end

      domain = Discourse.current_hostname
      nonce = Siwe::Util.generate_nonce
      message = Siwe::Message.new(
        domain,
        eth_account,
        Discourse.base_url,
        "1",
        issued_at: Time.now.utc.iso8601,
        statement: SiteSetting.siwe_statement,
        nonce: nonce,
        chain_id: params[:chain_id],
      )

      session[:siwe_nonce] = nonce
      Rails.logger.info("[SIWE] issued SIWE message for #{eth_account}, nonce=#{nonce}")

      render json: { message: message.prepare_message }
    end

    # Step 2: frontend sends back signature + address
    def callback
      message   = params[:message]
      signature = params[:signature]
      address   = params[:address]

      Rails.logger.info("[SIWE] /callback called with address=#{address.inspect}, signature=#{signature&.slice(0,10)}..., message_len=#{message&.length}")

      begin
        siwe_msg = Siwe::Message.from_message(message)
        Rails.logger.info("[SIWE] parsed SIWE message: #{siwe_msg.to_h}")

        siwe_msg.verify(
          signature: signature,
          domain: Discourse.current_hostname,
          nonce: session[:siwe_nonce]
        )

        Rails.logger.info("[SIWE] signature verified OK for #{address}")

        # find or create the user
        user = User.find_by_custom_fields("eth_address" => address)
        unless user
          user = User.create!(
            username: "eth-#{address[2,6]}",
            name: address,
            custom_fields: { "eth_address" => address }
          )
          Rails.logger.info("[SIWE] created new user id=#{user.id} for #{address}")
        end

        log_on_user(user)
        Rails.logger.info("[SIWE] logged on user #{user.username} (#{address})")

        redirect_to "/"
      rescue => e
        Rails.logger.error("[SIWE] Verification failed: #{e.class}: #{e.message}\n#{e.backtrace.take(5).join("\n")}")
        render plain: "Authentication failed: #{e}", status: 401
      end
    end
  end
end
