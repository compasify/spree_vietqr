# SpreeVietqr

VietQR payment gateway extension for Spree Commerce.

Integrates bank transfer via QR code (VietQR standard) as a payment method for the Vietnamese market.

## Features

- QR code generation for bank transfers (via img.vietqr.io)
- Manual payment confirmation by admin
- Webhook auto-confirmation (Casso/SePay) — Phase 5
- Transfer content matching by order number

## Installation

Add to your Spree application's Gemfile:

```ruby
gem 'spree_vietqr', path: '../gems/spree_vietqr'
```

Run:
```bash
bundle install
bin/rails g spree_vietqr:install
```

## Configuration

Enable the payment method in Spree Admin -> Settings -> Payments, then add one or more VietQR receiving accounts from the payment method's VietQR account management screen. Provider credentials are configured per receiving account.

## License

MIT
