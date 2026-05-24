# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::PaymentInfo do
  let(:payment_method) do
    double("Spree::PaymentMethod::Vietqr")
  end

  let(:payment) { double('Spree::Payment', amount: 250_000) }
  let(:payments_relation) { double('PaymentsRelation') }
  let(:allocation) do
    double(
      'SpreeVietqr::PaymentAllocation',
      bank_bin: bank_bin,
      account_number: account_number,
      account_name: account_name,
      expected_amount: 250_000,
      transfer_content: 'MMOR123456789',
      order_number: 'R123456789',
      provider_checkout_url: nil,
      payment_link_id: nil,
      provider_qr_code: nil
    )
  end

  let(:bank_bin) { '970422' }
  let(:account_number) { '0123456789' }
  let(:account_name) { 'NGUYEN VAN A' }

  let(:order) do
    double("Spree::Order", number: "R123456789", total: 250_000, payments: payments_relation)
  end

  subject { described_class.new(payment_method: payment_method, order: order) }

  before do
    allow(payments_relation).to receive(:where).and_return(payments_relation)
    allow(payments_relation).to receive(:order).with(:id).and_return(payments_relation)
    allow(payments_relation).to receive(:last).and_return(payment)
    allow(SpreeVietqr::AllocatePaymentAccount).to receive(:new)
      .and_return(double('Allocator', call: allocation))
  end

  describe '#to_h' do
    it "returns complete payment info hash" do
      result = subject.to_h

      expect(result).to include(
        qr_url: a_string_including("img.vietqr.io"),
        bank_name: "MB Bank",
        account_number: "0123456789",
        account_name: "NGUYEN VAN A",
        amount: 250_000,
        currency: "VND",
        transfer_content: "MMOR123456789",
        order_number: "R123456789"
      )
    end
  end

  describe '#bank_name' do
    it "resolves known bank BIN" do
      expect(subject.bank_name).to eq("MB Bank")
    end

    context "with unknown BIN" do
      let(:bank_bin) { '999999' }
      let(:account_name) { 'TEST' }

      it "returns fallback name" do
        expect(subject.bank_name).to eq("Bank 999999")
      end
    end
  end

  describe '#transfer_content' do
    it "formats as MMO + order number" do
      expect(subject.transfer_content).to eq("MMOR123456789")
    end
  end

  describe '#amount' do
    it "returns integer VND amount" do
      expect(subject.amount).to eq(250_000)
      expect(subject.amount).to be_a(Integer)
    end
  end

  describe '#qr_url' do
    it "delegates to GenerateQr service" do
      expect(subject.qr_url).to include("img.vietqr.io/image/970422-0123456789-compact2.png")
      expect(subject.qr_url).to include("amount=250000")
      expect(subject.qr_url).to include("addInfo=MMOR123456789")
    end
  end
end
