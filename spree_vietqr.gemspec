# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spree_vietqr/version'

Gem::Specification.new do |s|
  s.name        = 'spree_vietqr'
  s.version     = SpreeVietqr::VERSION
  s.authors     = ['Omni Store Team']
  s.email       = ['dev@omnistore.vn']
  s.summary     = 'VietQR payment gateway for Spree Commerce 6'
  s.description = 'Integrates VietQR (bank transfer via QR) as a payment method in Spree Commerce 6 for the Vietnamese market'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 3.3'

  s.files = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']
  s.require_paths = ['lib']

  s.add_dependency 'spree_api', '>= 6.0', '< 7.0'
  s.add_dependency 'spree_core', '>= 6.0', '< 7.0'
end
