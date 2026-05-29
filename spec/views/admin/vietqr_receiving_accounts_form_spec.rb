# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'spree/admin/vietqr_receiving_accounts/_form.html.erb' do
  subject(:template) { File.read(File.expand_path('../../../app/views/spree/admin/vietqr_receiving_accounts/_form.html.erb', __dir__)) }

  it 'keeps provider and account fields outside the provider-toggleable webhook section' do
    account_fields_position = template.index('data: { vietqr_account_provider_select: true }')
    webhook_marker_position = template.index('data-vietqr-webhook-card')
    webhook_section_position = template.index('data-vietqr-provider-help="sepay"')

    expect(account_fields_position).to be < webhook_marker_position
    expect(webhook_marker_position).to be < webhook_section_position
  end
end
