# Spree VietQR

VietQR payment extension for Spree Commerce. Gem này thêm payment method `Spree::PaymentMethod::Vietqr`, cho phép khách thanh toán chuyển khoản ngân hàng bằng QR code và tự động đối soát qua webhook SePay hoặc PayOS.

## Tính năng hiện có

- Payment method `vietqr` không cần payment source, không auto-capture khi checkout.
- Quản lý nhiều tài khoản nhận tiền cho từng payment method trong Spree Admin.
- Sinh QR VietQR qua `https://img.vietqr.io/image` cho provider `manual` và `sepay`.
- Tạo PayOS payment link khi tài khoản nhận tiền dùng provider `payos`.
- Cấp phát tài khoản nhận tiền theo từng payment đang pending để chống đổi tài khoản giữa các lần hiển thị QR.
- Chọn tài khoản theo chiến lược `single`, `round_robin`, `random`, hoặc `quota_waterfall`.
- Hạn mức tháng, ngưỡng chuyển tài khoản, số tiền đã cấp phát và số tiền đã xác nhận theo từng tài khoản.
- Webhook endpoint cho SePay và PayOS, lưu raw payload/header vào `SpreeVietqr::WebhookEvent`.
- Tự động khớp webhook theo provider, mã đơn, số tiền và tài khoản đã cấp phát.
- Xử lý webhook trùng, webhook không khớp, retry processing và manual match trong admin.
- Ghi nhận thiếu/thừa tiền vào store credit cho order có user.

## Yêu cầu

- Ruby `>= 3.2`
- Spree `>= 5.4.0`
- Rails app có PostgreSQL hoặc database hỗ trợ `jsonb` như các migration hiện tại.

## Cài đặt

Thêm gem vào `Gemfile` của Spree app:

```ruby
gem 'spree_vietqr', path: '../gems/spree_vietqr'
```

Chạy bundle và installer:

```bash
bundle install
bin/rails g spree_vietqr:install
```

Installer sẽ copy migrations từ gem và mặc định chạy `db:migrate`. Nếu muốn tự chạy migrate sau, chạy generator với `--no-migrate` và trả lời `n` khi được hỏi:

```bash
bin/rails g spree_vietqr:install --no-migrate
bin/rails db:migrate
```

## Database

Gem tạo các bảng chính:

- `spree_vietqr_receiving_accounts`: tài khoản nhận tiền, provider, credential webhook/API, hạn mức và routing metadata.
- `spree_vietqr_payment_allocations`: snapshot tài khoản đã cấp phát cho từng payment/order.
- `spree_vietqr_webhook_events`: raw webhook, trạng thái xử lý, dữ liệu đã parse và liên kết payment/allocation.

## Cấu hình trong Admin

1. Vào `Admin -> Settings -> Payments`.
2. Tạo hoặc sửa payment method dùng type `Spree::PaymentMethod::Vietqr`.
3. Chọn `Cách chọn tài khoản`:
   - `single`: chọn tài khoản active có `priority` nhỏ nhất và còn đủ hạn mức.
   - `round_robin`: chọn tài khoản lâu nhất chưa được cấp phát.
   - `random`: chọn ngẫu nhiên trong nhóm đủ điều kiện.
   - `quota_waterfall`: ưu tiên tài khoản chưa chạm `monthly_threshold_amount`, sau đó fallback theo `priority`.
4. Lưu payment method trước, sau đó vào màn hình `Tài khoản nhận tiền` để thêm receiving account.

Gem cũng thêm menu admin:

- `/admin/vietqr_payment_methods`: tổng quan payment method VietQR và tài khoản nhận tiền.
- `/admin/payment_methods/:payment_method_id/vietqr_receiving_accounts`: quản lý tài khoản nhận tiền.
- `/admin/webhook_events`: xem, lọc, manual match và retry webhook events.

## Receiving Account

Mỗi receiving account thuộc một `Spree::PaymentMethod::Vietqr` và có các trường quan trọng:

- `provider`: một trong `manual`, `sepay`, `payos`.
- `bank_bin`: BIN ngân hàng dùng để sinh QR VietQR.
- `bank_name`: tên ngân hàng để hiển thị trong admin.
- `account_number`: số tài khoản nhận tiền.
- `account_name`: tên chủ tài khoản.
- `keyword_init`: tiền tố nội dung chuyển khoản. Nếu trống, hệ thống dùng `MMO`.
- `sub_account`: định danh phụ, dùng khi provider trả về sub account.
- `virtual_account_number`: số tài khoản ảo, dùng khi provider trả về virtual account.
- `active`: chỉ tài khoản active mới được chọn khi cấp phát.
- `priority`: số nhỏ hơn được ưu tiên hơn.
- `routing_weight`: hiện được validate và lưu, chưa được dùng trong thuật toán chọn tài khoản.
- `monthly_quota_amount`: hạn mức tháng. Trống hoặc `0` nghĩa là không giới hạn.
- `monthly_threshold_amount`: ngưỡng để `quota_waterfall` chuyển ưu tiên sang tài khoản khác.

Credential theo provider:

- `manual`: không cần credential.
- `sepay`: bắt buộc `webhook_secret`.
- `payos`: bắt buộc `payos_client_id`, `payos_api_key`, `payos_checksum_key`.

Nếu xóa một account đã có allocations, controller sẽ tắt `active` thay vì xóa record.

## Luồng thanh toán

Khi Spree hoàn tất checkout bằng VietQR, `authorize` trả success ngay với authorization code dạng `VIETQR-...`. Tiền thật vẫn ở trạng thái chờ cho đến khi được xác nhận qua webhook hoặc thao tác admin.

Khi ứng dụng cần hiển thị QR, dùng service:

```ruby
payment_info = SpreeVietqr::PaymentInfo.new(
  payment_method: payment_method,
  order: order,
  request_base_url: request.base_url
)

payment_info.to_h
```

Kết quả trả về:

```ruby
{
  qr_url: "https://img.vietqr.io/image/970422-0123456789-compact2.png?...",
  bank_name: "MB Bank",
  account_number: "0123456789",
  account_name: "NGUYEN VAN A",
  amount: 250000,
  currency: "VND",
  transfer_content: "MMOR123456789",
  order_number: "R123456789",
  checkout_url: nil,
  payment_link_id: nil
}
```

`PaymentInfo` chỉ hoạt động khi order có VietQR payment ở state `checkout`, `pending`, hoặc `processing`. Nếu không có payment phù hợp, service raise `ActiveRecord::RecordNotFound`.

Với provider `payos`, service sẽ gọi PayOS API để tạo payment link. Khi PayOS trả về `checkoutUrl`, `qrCode` và `paymentLinkId`, các giá trị này được lưu vào allocation và trả ra qua `checkout_url`, `qr_url`, `payment_link_id`.

## Allocation

Mỗi lần lấy payment info, gem sẽ cấp phát hoặc tái sử dụng một `SpreeVietqr::PaymentAllocation` active cho payment hiện tại.

Allocation lưu snapshot:

- payment, order, payment method, receiving account.
- provider, bank/account info, số tiền cần nhận.
- `transfer_content` theo format `#{keyword_init.presence || 'MMO'}#{order.number}`.
- `order_number`.
- PayOS metadata nếu có: `provider_order_code`, `payment_link_id`, `provider_checkout_url`, `provider_qr_code`.
- `expires_at`, mặc định là `order.created_at + 10.minutes`.

Nếu payment đã có allocation active, hệ thống tái sử dụng allocation đó. Nếu order đổi payment VietQR khác, allocation cũ cùng order/payment method sẽ được release.

## QR Code

Provider `manual` và `sepay` dùng `SpreeVietqr::GenerateQr` để tạo URL ảnh VietQR:

```text
https://img.vietqr.io/image/:bank_bin-:account_number-compact2.png?amount=:amount&addInfo=:transfer_content&accountName=:account_name
```

Nếu allocation có `provider_qr_code` là URL HTTP/HTTPS, gem dùng URL đó trực tiếp. Đây là trường hợp PayOS trả về QR code riêng.

## Webhook

Gem mount engine tại root app và thêm endpoint:

```text
POST /webhooks/payments/:provider
```

Provider được hỗ trợ:

- `POST /webhooks/payments/sepay`
- `POST /webhooks/payments/payos`

Middleware `SpreeVietqr::RawBodyMiddleware` lưu raw body vào `request.env['spree_vietqr.raw_body']` cho các webhook path. Raw body này được dùng để verify chữ ký.

### SePay

SePay webhook cần headers:

- `X-SePay-Signature`: `sha256=` + HMAC-SHA256 của `"#{timestamp}.#{raw_body}"` bằng `webhook_secret`.
- `X-SePay-Timestamp`: Unix timestamp, lệch tối đa 300 giây.

Payload được parse khi `transferType` là `in`. Các field đang dùng:

- `id`: transaction id.
- `transferAmount`: số tiền nhận.
- `code` hoặc `content`: nội dung chuyển khoản để tách mã order.
- `accountNumber`, `gateway`, `subAccount`: dùng để đối chiếu tài khoản nhận.
- `referenceCode`, `transactionDate`: thông tin tham chiếu.

Mã order được tách từ nội dung có prefix mặc định `MMO` hoặc `keyword_init`, ví dụ `MMOR123456789` hoặc `DHR123456789`.

### PayOS

PayOS webhook dùng `payos_checksum_key` để verify `signature` trên object `data` theo format PayOS: sort keys, nối `key=value` bằng `&`, sau đó HMAC-SHA256.

Payload thành công khi `data.code == '00'`. Các field đang dùng:

- `data.amount`: số tiền nhận.
- `data.orderCode`: mã order của PayOS. Gem reconstruct thành `R#{orderCode}`.
- `data.paymentLinkId`: ưu tiên dùng để match allocation.
- `data.accountNumber`, `data.virtualAccountNumber`: đối chiếu tài khoản nhận.
- `data.reference`, `data.transactionDateTime`, `data.description`: thông tin tham chiếu.

Lưu ý: khi tạo PayOS payment link, gem gửi `orderCode = order.number.gsub(/\D/, '').to_i`, nên luồng PayOS phù hợp nhất với order number chuẩn dạng `R` + chữ số.

## Đối soát và xác nhận payment

Webhook được xử lý bởi `SpreeVietqr::ProcessWebhook`:

1. Verify credential theo provider và receiving account active.
2. Lưu raw event vào `spree_vietqr_webhook_events`.
3. Bỏ qua event trùng nếu provider transaction id đã được xử lý.
4. Normalize payload thành `SpreeVietqr::NormalizedTransaction`.
5. Tìm allocation bằng `payment_link_id`, `provider_order_code`, hoặc `order_number`.
6. Kiểm tra số tiền, tài khoản nhận, bank/bin/sub account/virtual account.
7. Gọi `SpreeVietqr::ConfirmPayment`.

Khi xác nhận thành công:

- Payment được `complete!` nếu số tiền nhận đủ.
- Allocation chuyển sang `confirmed`.
- Webhook event chuyển sang `confirmed`.
- `period_confirmed_amount` của receiving account được tăng.
- Nếu có `Mmo::DeliverOrderJob`, order MMO đã paid sẽ được enqueue delivery.

Nếu nhận thiếu tiền và order có user, số tiền nhận được cộng vào store credit, order vẫn chưa paid. Nếu nhận thừa tiền, phần thừa được cộng vào store credit.

## Admin xử lý webhook lỗi

Trong `/admin/webhook_events`, admin có thể:

- Lọc webhook theo provider hoặc status.
- Xem raw payload/header.
- `Khớp thủ công` một event `unmatched` hoặc `error` với order number cụ thể.
- `Xử lý lại` để parse và match lại event.

Manual match vẫn kiểm tra số tiền và tài khoản allocation trước khi confirm payment.

## Trạng thái webhook

Các status chính của `SpreeVietqr::WebhookEvent`:

- `received`: đã nhận raw webhook.
- `verified`: chữ ký hợp lệ.
- `rejected`: credential/chữ ký không hợp lệ.
- `duplicate`: event trùng hoặc payment/allocation đã confirmed.
- `unmatched`: không tìm được allocation/payment phù hợp.
- `matched`: đã match allocation, đang confirm.
- `confirmed`: payment đã được xác nhận hoặc số tiền đã được credit theo logic underpayment.
- `error`: lỗi trong quá trình xử lý.

## Routes

Engine routes:

```text
POST /webhooks/payments/:provider
```

Admin routes được thêm vào `Spree::Core::Engine`:

```text
GET    /admin/vietqr_payment_methods
GET    /admin/payment_methods/:payment_method_id/vietqr_receiving_accounts
POST   /admin/payment_methods/:payment_method_id/vietqr_receiving_accounts
PATCH  /admin/payment_methods/:payment_method_id/vietqr_receiving_accounts/:id
DELETE /admin/payment_methods/:payment_method_id/vietqr_receiving_accounts/:id
GET    /admin/webhook_events
GET    /admin/webhook_events/:id
POST   /admin/webhook_events/:id/manual_match
POST   /admin/webhook_events/:id/retry_processing
```

## Testing

Chạy test của gem:

```bash
cd gems/spree_vietqr
bundle exec rspec
```

## License

MIT
