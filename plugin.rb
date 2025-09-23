# frozen_string_literal: true

# name: discourse-siwe
# about: A discourse plugin to enable users to authenticate via Sign In with Ethereum
# version: 0.1.3

enabled_site_setting :discourse_siwe_enabled
register_svg_icon 'fab-ethereum'
register_asset 'stylesheets/discourse-siwe.scss'

# Carrega a strategy
%w[
  ../lib/omniauth/strategies/siwe.rb
].each { |path| load File.expand_path(path, __FILE__) }

# Dependências SIWE
gem 'pkg-config', '1.5.6'
gem 'forwardable', '1.3.3'
gem 'mkmfmf', '0.4'
gem 'keccak', '1.3.0'
gem 'zip', '2.0.2'
gem 'mini_portile2', '2.8.0'
gem 'rbsecp256k1', '6.0.0'
gem 'konstructor', '1.0.2'
gem 'ffi', '1.17.2'
gem 'ffi-compiler', '1.0.1'
gem 'scrypt', '3.0.7'
gem 'eth', '0.5.11'
gem 'siwe', '1.1.2'

class ::SiweAuthenticator < ::Auth::ManagedAuthenticator
  def name
    "siwe"
  end

  def register_middleware(omniauth)
    omniauth.provider :siwe
  end

  def enabled?
    SiteSetting.discourse_siwe_enabled
  end

  def primary_email_verified?
    true
  end
end

auth_provider authenticator: ::SiweAuthenticator.new,
              icon: "fab-ethereum",
              full_screen_login: true,
              title: "Sign in with Ethereum"

after_initialize do
  # Se for expor rotas extras além do OmniAuth, mantém
  %w[
    ../lib/discourse_siwe/engine.rb
    ../lib/discourse_siwe/routes.rb
    ../app/controllers/discourse_siwe/auth_controller.rb
  ].each { |path| load File.expand_path(path, __FILE__) }

  Discourse::Application.routes.prepend do
    mount ::DiscourseSiwe::Engine, at: "/discourse-siwe"
  end
end
