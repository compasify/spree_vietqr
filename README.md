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

Set environment variables:

```bash
VIETQR_BANK_BIN=970422
VIETQR_ACCOUNT_NUMBER=0123456789
VIETQR_ACCOUNT_NAME=NGUYEN VAN A
VIETQR_PROVIDER=manual          # sepay | casso | manual
VIETQR_WEBHOOK_SECRET=xxx
VIETQR_AUTO_CONFIRM_GRACE_SECONDS=60
```

Then enable the payment method in Spree Admin → Settings → Payments.

## License

MIT
