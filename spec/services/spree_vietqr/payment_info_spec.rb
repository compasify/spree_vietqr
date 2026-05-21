# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::PaymentInfo do
  let(:payment_method) do
    double(
      "Spree::PaymentMethod::Vietqr",
      preferred_bank_bin: "970422",
      preferred_account_number: "0123456789",
      preferred_account_name: "NGUYEN VAN A"
    )
  end

  let(:order) do
    double("Spree::Order", number: "R123456789", total: 250_000)
  end

  subject { described_class.new(payment_method: payment_method, order: order) }

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
      let(:payment_method) do
        double(
          "Spree::PaymentMethod::Vietqr",
          preferred_bank_bin: "999999",
          preferred_account_number: "0123456789",
          preferred_account_name: "TEST"
        )
      end

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
