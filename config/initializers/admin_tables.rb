# frozen_string_literal: true

Rails.application.config.after_initialize do
  next unless Spree.respond_to?(:admin) && Spree.admin.respond_to?(:tables)

  Spree.admin.tables.register(:vietqr_webhook_events, model_class: SpreeVietqr::WebhookEvent, search_param: :provider_transaction_id_or_matched_order_number_or_parsed_order_code_cont, row_actions: false, new_resource: false)

  Spree.admin.tables.vietqr_webhook_events.add :id,
    label: 'ID',
    type: :string,
    sortable: true,
    filterable: false,
    default: true,
    position: 10,
    method: ->(event) { "##{event.id}" }

  Spree.admin.tables.vietqr_webhook_events.add :provider,
    label: 'Provider',
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 20

  Spree.admin.tables.vietqr_webhook_events.add :status,
    label: :status,
    type: :status,
    filter_type: :select,
    sortable: true,
    filterable: true,
    default: true,
    position: 30,
    operators: %i[eq in],
    value_options: -> { SpreeVietqr::WebhookEvent::STATUSES.map { |status| { value: status, label: status.humanize } } }

  Spree.admin.tables.vietqr_webhook_events.add :amount_cents,
    label: 'Amount',
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 40,
    method: ->(event) { event.amount_cents.present? ? event.amount_cents.to_s : nil }

  Spree.admin.tables.vietqr_webhook_events.add :resolved_order_number,
    label: :order,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 50,
    method: ->(event) { event.matched_order_number.presence || event.parsed_order_code }

  Spree.admin.tables.vietqr_webhook_events.add :created_at,
    label: :created_at,
    type: :datetime,
    sortable: true,
    filterable: true,
    default: true,
    position: 60

  Spree.admin.tables.vietqr_webhook_events.add :actions,
    label: 'Actions',
    type: :custom,
    sortable: false,
    filterable: false,
    default: true,
    position: 70,
    align: :right,
    partial: 'spree/admin/webhook_events/table_actions',
    partial_locals: ->(record) { { event: record } }
end
