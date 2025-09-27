# frozen_string_literal: true
require 'siwe'
require 'eth'

module DiscourseSiwe
  class AuthController < ::ApplicationController
    skip_before_action :redirect_to_login_if_required, only: [:index, :message, :callback]

    # Public landing that boots the Ember route and opens AppKit
    def index
      render html: "".html_safe, layout: true
    end

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
      nonce     = params[:nonce]

      Rails.logger.info("[SIWE] /callback called with:")
      Rails.logger.info("  address=#{address.inspect}")
      Rails.logger.info("  signature=#{signature&.slice(0,10)}...")
      Rails.logger.info("  message_len=#{message&.length}")
      Rails.logger.info("  nonce=#{nonce.inspect}")
      Rails.logger.info("  session_nonce=#{session[:siwe_nonce].inspect}")
      Rails.logger.info("  all_params=#{params.to_unsafe_h.keys.join(', ')}")

      begin
        siwe_msg = Siwe::Message.from_message(message)
        Rails.logger.info("[SIWE] parsed SIWE message: #{siwe_msg.to_h}")

        # Use nonce from params if available, otherwise fall back to session
        validation_nonce = nonce.presence || session[:siwe_nonce]
        Rails.logger.info("[SIWE] Using nonce for validation: #{validation_nonce.inspect}")
        
        siwe_msg.verify(
          signature: signature,
          domain: Discourse.current_hostname,
          nonce: validation_nonce
        )

        Rails.logger.info("[SIWE] signature verified OK for #{address}")

        # normalize wallet address (lowercase) and build synthetic credentials
        wallet = address.to_s.downcase
        email = "#{wallet}@wallet.local"
        # base username: eth_ + first 12 hex chars after 0x
        base_uname = "eth_#{wallet.sub(/^0x/, '')[0, 12]}"
        uname = base_uname

        # try to find existing user by custom field or email
        user = User.find_by_custom_fields("eth_account" => wallet) || User.find_by_email(email)

        unless user
          # ensure username uniqueness
          suffix = 0
          while User.where(username: uname).exists?
            suffix += 1
            uname = suffix == 1 ? "#{base_uname}" : "#{base_uname}_#{suffix}"
          end

          user = User.new(
            username: uname,
            name: uname,
            email: email,
            active: true
          )

          # attach wallet as custom field
          user.custom_fields["eth_account"] = wallet

          # save user; bypass email confirmation requirements
          user.save!(validate: false)
          Rails.logger.info("[SIWE] created new user id=#{user.id} username=#{user.username} for #{wallet}")
        end

        # Log in and redirect
        log_on_user(user)
        Rails.logger.info("[SIWE] logged on user #{user.username} (#{address})")

        redirect_to "/"
        return
      rescue => e
        Rails.logger.error("[SIWE] Verification failed: #{e.class}: #{e.message}\n#{e.backtrace.take(5).join("\n")}")
        render plain: "Authentication failed: #{e}", status: 401
      end
    end
  end
end
