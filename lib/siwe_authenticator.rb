# frozen_string_literal: true

class SiweAuthenticator < ::Auth::ManagedAuthenticator
  def name
    "siwe"
  end

  def register_middleware(omniauth)
    omniauth.provider :siwe
  end

  def after_authenticate(auth_token, existing_account: nil)
    eth_address = auth_token[:info]["eth_address"].downcase
    result = Auth::Result.new

    # Find existing user by custom field
    user = User.find_by_custom_fields("eth_account" => eth_address)

    unless user
      # Create new user with auto-generated username
      base_username = "eth_#{eth_address[2, 12]}"
      username = base_username
      counter = 0
      
      # Ensure username uniqueness
      while User.where(username: username).exists?
        counter += 1
        username = "#{base_username}_#{counter}"
      end

      email = "#{eth_address}@wallet.local"

      user = User.new(
        username: username,
        name: username,
        email: email,
        active: true,
        approved: true,
        email_confirmed: true
      )
      
      user.custom_fields["eth_account"] = eth_address
      user.save!(validate: false)
      
      Rails.logger.info("[SIWE] Created user #{username} for #{eth_address}")
    end

    result.user = user
    result.username = user.username
    result.email = user.email
    result.extra_data = { eth_address: eth_address }
    result.email_valid = true

    result
  end

  def enabled?
    SiteSetting.discourse_siwe_enabled
  end

  def primary_email_verified?
    false
  end
end
