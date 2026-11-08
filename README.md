# Spree VietQR

VietQR payment extension for Spree Commerce 6. Gem này thêm payment method `Spree::PaymentMethod::Vietqr` (API type `vietqr`), cho phép khách thanh toán chuyển khoản ngân hàng bằng QR code. Gem tự động đối soát giao dịch qua webhook SePay hoặc PayOS.

> **Phiên bản Spree 5.** Source code ở tag `v0.1.0-spree5` (và nhánh `spree-5-stable`) chỉ dành cho **Spree 5.4+** với admin Rails (`spree_admin`). Dự án Spree 5 nên khóa gem theo tag này:
>
> ```ruby
> gem 'spree_vietqr', github: 'compasify/spree_vietqr', tag: 'v0.1.0-spree5'
> ```
>
> Bản dành cho Spree 6 nằm ở nhánh `master` từ phiên bản `1.0.0`.

## Tính năng

- Payment method `vietqr`: không cần payment source, không cần session, capture thủ công (`resolved_capture_method = 'manual'`). Tiền được xác nhận bằng webhook ngân hàng hoặc thao tác của nhân viên.
- Nhiều tài khoản nhận tiền cho mỗi payment method, chọn theo chiến lược `single`, `round_robin`, `random` hoặc `quota_waterfall`, có hạn mức tháng và ngưỡng chuyển tài khoản.
- Sinh QR VietQR qua `https://img.vietqr.io/image` cho provider `manual` và `sepay`. Provider `payos` tạo PayOS payment link.
- Cấp phát (allocation) tài khoản cho từng payment đang chờ, để QR không đổi tài khoản giữa các lần hiển thị. Allocation hết hạn sau `payment_timeout_minutes`.
- Webhook SePay và PayOS: verify chữ ký, lưu raw payload/header, chống trùng, tự khớp theo mã đơn, số tiền và tài khoản.
- Admin API v3 cho tài khoản nhận tiền, allocation và webhook (khớp thủ công, xử lý lại). Store API trả QR của một đơn đã đặt.
- Thiếu tiền hoặc thừa tiền được ghi vào store credit của khách (`order.customer`).

## Yêu cầu

- Ruby `>= 3.3`
- Spree `>= 6.0, < 7.0` (`spree_core`, `spree_api`)
- PostgreSQL (migration dùng `jsonb`)
- Tùy chọn: Active Record Encryption. Khi app có primary key, các secret của tài khoản nhận tiền (`webhook_secret`, `payos_api_key`, `payos_checksum_key`) được mã hóa trong database.

## Cài đặt

```ruby
# Gemfile
gem 'spree_vietqr', github: 'compasify/spree_vietqr'
```

```bash
bundle install
bin/rails g spree_vietqr:install   # chỉ chạy db:migrate
```

Engine tự nạp migrations của gem (không copy vào app), tự đăng ký payment method vào `Spree.payment_methods` và permission scope `vietqr` vào `Spree.permissions`.

Trong dự án dùng Spree CLI, chạy qua CLI thay vì gọi trực tiếp: `pnpm spree bundle install`, `pnpm spree migrate`.

## Cấu hình

Mọi cấu hình nằm trong Admin Dashboard (React) hoặc gọi Admin API trực tiếp.

1. **Settings → Payment methods**: tạo payment method loại **VietQR**. Form preferences được dashboard sinh tự động từ schema:
   - `account_routing_strategy`: `single` (tài khoản active có `priority` nhỏ nhất còn hạn mức), `round_robin` (tài khoản lâu nhất chưa được cấp phát), `random`, `quota_waterfall` (ưu tiên tài khoản chưa chạm `monthly_threshold_amount`, sau đó theo `priority`).
   - `payment_timeout_minutes`: thời gian giữ QR, mặc định 15 phút.
   - `transfer_content_prefix`: tiền tố nội dung chuyển khoản, mặc định `MMO`. Mỗi tài khoản có thể ghi đè bằng `keyword_init`.
2. **Tài khoản nhận tiền**: thêm qua Admin API `.../vietqr/receiving_accounts`. Dashboard của dự án dùng gem có thể dựng trang riêng cho phần này; xem [Admin Dashboard](#admin-dashboard).

Các trường của receiving account:

| Trường | Ý nghĩa |
|---|---|
| `provider` | `manual`, `sepay` hoặc `payos` |
| `bank_bin`, `bank_name` | BIN ngân hàng (sinh QR) và tên hiển thị. `GET .../vietqr/banks` trả danh sách BIN đã biết |
| `account_number`, `account_name` | Số tài khoản (khoảng trắng bị bỏ) và chủ tài khoản |
| `keyword_init` | Tiền tố nội dung chuyển khoản riêng của tài khoản |
| `sub_account`, `virtual_account_number` | Dùng để đối chiếu khi provider trả về |
| `active`, `priority` | Chỉ tài khoản active được chọn. `priority` nhỏ hơn được ưu tiên |
| `routing_weight` | Được lưu và validate, chưa chiến lược nào dùng |
| `monthly_quota_amount`, `monthly_threshold_amount` | Hạn mức tháng (trống hoặc `0` là không giới hạn) và ngưỡng của `quota_waterfall` |
| `webhook_secret` | Bắt buộc với `sepay` |
| `payos_client_id`, `payos_api_key`, `payos_checksum_key` | Bắt buộc với `payos` |

API không bao giờ trả secret. Secret đã lưu được trả về dạng `••••` + 4 ký tự cuối. Khi cập nhật, giá trị trống hoặc giá trị còn mask sẽ bị bỏ qua, nên secret cũ được giữ nguyên. Xóa một tài khoản đã từng được cấp phát sẽ tắt `active` thay vì xóa record.

## Luồng thanh toán

Gem chỉ ghi nhận tiền khi ngân hàng báo hoặc khi có người xác nhận. Spree 6 không còn state machine: payment chuyển trạng thái qua cột `status` (`checkout`, `pending`, `processing`, `completed`, `void`, `failed`, `invalid`).

1. Đơn có một payment VietQR ở trạng thái `checkout`, `pending` hoặc `processing`.
2. Khi cần hiện QR, `SpreeVietqr::PaymentInfo` (hoặc `SpreeVietqr::AllocatePaymentAccount`) cấp phát hoặc dùng lại một `SpreeVietqr::PaymentAllocation`. Allocation lưu snapshot gồm tài khoản, số tiền, nội dung chuyển khoản `#{prefix}#{order.number}` và `expires_at`.
3. Khách chuyển khoản. Webhook đến `POST /webhooks/payments/:provider` và được xử lý bởi `SpreeVietqr::ProcessWebhook`: verify, lưu event, chống trùng, chuẩn hóa, tìm allocation (theo `payment_link_id`, `provider_order_code` hoặc mã đơn), kiểm tra số tiền và tài khoản, rồi gọi `SpreeVietqr::ConfirmPayment`.
4. Khi xác nhận thành công, payment chuyển sang `completed`, allocation và webhook event chuyển sang `confirmed`, và `period_confirmed_amount` của tài khoản tăng lên.

```ruby
SpreeVietqr::OrderPaymentSummary.call(order: order, request_base_url: request.base_url)
# => { status: 'allocated', qr_url: 'https://img.vietqr.io/image/970436-0123456789-compact2.png?...',
#      bank_name: 'Vietcombank', account_number: '0123456789', account_name: 'PARK VIET',
#      amount: 250000, currency: 'VND', transfer_content: 'MMOR123456789', expires_at: ..., payment_id: ...,
#      order_payment_status: 'none' }
# Khi đã nhận tiền: { status: 'confirmed', amount:, transfer_content:, confirmed_at:, payment_id:, order_payment_status: }
```

Với provider `payos`, gem gọi PayOS API để tạo payment link và trả `checkout_url`, `qr_url`, `payment_link_id`. PayOS dùng `orderCode = order.number.gsub(/\D/, '').to_i`, nên luồng này hợp nhất với số đơn dạng `R` + chữ số.

`SpreeVietqr::ExpireAllocationsJob` giải phóng các allocation đã hết hạn của payment chưa thanh toán.

## Webhook

```text
POST /webhooks/payments/sepay
POST /webhooks/payments/payos
```

`SpreeVietqr::RawBodyMiddleware` giữ raw body để verify chữ ký.

- **SePay**: header `X-SePay-Signature` = `sha256=` + HMAC-SHA256 của `"#{timestamp}.#{raw_body}"` bằng `webhook_secret`. Header `X-SePay-Timestamp` lệch tối đa 300 giây. Chỉ xử lý `transferType == 'in'`. Gem dùng các trường `id`, `transferAmount`, `code`/`content`, `accountNumber`, `gateway`, `subAccount`, `referenceCode` và `transactionDate`.
- **PayOS**: verify `signature` trên object `data` bằng `payos_checksum_key`. Giao dịch thành công khi `data.code == '00'`.

Trạng thái webhook event:

| Trạng thái | Ý nghĩa |
|---|---|
| `received` | Đã nhận raw webhook |
| `verified` | Chữ ký hợp lệ |
| `rejected` | Credential hoặc chữ ký không hợp lệ |
| `duplicate` | Event trùng, hoặc payment đã được xác nhận |
| `unmatched` | Không tìm được allocation phù hợp |
| `matched` | Đã khớp allocation, đang xác nhận |
| `confirmed` | Payment đã được xác nhận, hoặc đã ghi store credit khi thiếu tiền |
| `error` | Lỗi khi xử lý |

Một event `unmatched` hoặc `error` có thể được khớp thủ công với một số đơn, hoặc được xử lý lại. Khớp thủ công vẫn kiểm tra số tiền và tài khoản của allocation.

## Admin API

Mọi route nằm dưới `/api/v3/admin/vietqr`. Secret key cần scope `read_vietqr` hoặc `write_vietqr`. Nhân viên được phân quyền theo role trên `SpreeVietqr::ReceivingAccount`, `SpreeVietqr::PaymentAllocation` và `SpreeVietqr::WebhookEvent`.

```text
GET    /api/v3/admin/vietqr/banks
GET    /api/v3/admin/vietqr/receiving_accounts?payment_method_id=pm_...
GET    /api/v3/admin/vietqr/receiving_accounts/:id
POST   /api/v3/admin/vietqr/receiving_accounts          (payment_method_id bắt buộc)
PATCH  /api/v3/admin/vietqr/receiving_accounts/:id
DELETE /api/v3/admin/vietqr/receiving_accounts/:id
GET    /api/v3/admin/vietqr/payment_allocations
GET    /api/v3/admin/vietqr/payment_allocations/:id
GET    /api/v3/admin/vietqr/webhook_events?status=&provider=&q=
GET    /api/v3/admin/vietqr/webhook_events/:id
POST   /api/v3/admin/vietqr/webhook_events/:id/manual_match   { order_number }
POST   /api/v3/admin/vietqr/webhook_events/:id/retry_processing
```

Danh sách trả `{ data, meta: { page, per_page, count, pages } }`, với `per_page` tối đa 100. Mọi id là prefixed id (`vqracct_…`, `vqralloc_…`, `vqrevt_…`).

## Store API

```text
GET /api/v3/store/orders/:id/vietqr
```

Endpoint trả QR (hoặc trạng thái đã nhận tiền) của một đơn đã đặt. Request cần publishable key và token của đơn (header `x-spree-token`), hoặc khách sở hữu đơn. Đơn không trả bằng VietQR nhận `422`. Storefront có thể hiện QR ở trang cảm ơn và gọi lại endpoint này cho đến khi `status` là `confirmed`.

## Admin Dashboard

Gem chỉ cung cấp API. Dashboard tự sinh form cho preferences của payment method. Trang quản lý tài khoản nhận tiền và webhook là một plugin của dashboard trong dự án dùng gem. Ví dụ ở dự án ParkViet: `apps/dashboard/src/pages/vietqr-settings.tsx`, đăng ký ở **Settings → VietQR**.

## Testing

```bash
cd spree_vietqr
bundle exec rspec
```

Trong một app Spree dùng Spree CLI (gem nằm ở `vendor/gems/spree_vietqr`):

```bash
pnpm spree exec sh -c 'cd vendor/gems/spree_vietqr && BUNDLE_GEMFILE=/rails/Gemfile bundle exec rspec'
```

## License

MIT
