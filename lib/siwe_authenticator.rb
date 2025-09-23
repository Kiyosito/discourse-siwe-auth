# frozen_string_literal: true

class SiweAuthenticator < ::Auth::Authenticator
  def name
    "siwe"
  end

  def after_authenticate(auth_token, existing_account: nil)
    eth_address = auth_token[:info]["eth_address"].downcase
    result = Auth::Result.new

    # Find existing user by eth_account
    user = User.joins(:user_custom_fields)
               .find_by(user_custom_fields: { name: "eth_account", value: eth_address })

    unless user
      # Create new user
      username = "eth_" + eth_address[2..8]
      email = "#{eth_address}@siwe.local"

      user = User.new(username: username, email: email, active: true)
      user.custom_fields["eth_account"] = eth_address
      user.save!
    end

    result.user = user
    result.username = user.username
    result.email = user.email
    result.extra_data = { eth_address: eth_address }

    result
  end

  def enabled?
    SiteSetting.discourse_siwe_enabled
  end
end
