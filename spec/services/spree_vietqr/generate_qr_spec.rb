# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SpreeVietqr::GenerateQr do
  subject { described_class.new }

  let(:payment_method) do
    double(
      "Spree::PaymentMethod::Vietqr",
      active_receiving_accounts: [receiving_account]
    )
  end

  let(:receiving_account) do
    double(
      'SpreeVietqr::ReceivingAccount',
      bank_bin: '970422',
      account_number: '0123456789',
      account_name: 'NGUYEN VAN A'
    )
  end

  let(:order) do
    double("Spree::Order", number: "R123456789", total: 150_000)
  end

  describe '#call' do
    it "generates correct VietQR URL with base path" do
      url = subject.call(payment_method: payment_method, order: order)

      expect(url).to include("https://img.vietqr.io/image/970422-0123456789-compact2.png")
    end

    it "includes amount parameter" do
      url = subject.call(payment_method: payment_method, order: order)

      expect(url).to include("amount=150000")
    end

    it "includes transfer content with MMO prefix" do
      url = subject.call(payment_method: payment_method, order: order)

      expect(url).to include("addInfo=MMOR123456789")
    end

    it "includes URL-encoded account name" do
      url = subject.call(payment_method: payment_method, order: order)

      expect(url).to include("accountName=NGUYEN+VAN+A")
    end

    context "with Vietnamese diacritics in account name" do
      let(:receiving_account) do
        double(
          'SpreeVietqr::ReceivingAccount',
          bank_bin: '970436',
          account_number: '9876543210',
          account_name: 'NGUYỄN VĂN B'
        )
      end

      it "properly encodes Vietnamese characters" do
        url = subject.call(payment_method: payment_method, order: order)

        expect(url).to include("img.vietqr.io/image/970436-9876543210-compact2.png")
        # URI.encode_www_form handles UTF-8 encoding
        expect(url).not_to include(" ")
      end
    end

    context "with decimal total" do
      let(:order) do
        double("Spree::Order", number: "R999", total: 99_500.75)
      end

      it "truncates to integer VND" do
        url = subject.call(payment_method: payment_method, order: order)

        expect(url).to include("amount=99500")
        expect(url).not_to include("99500.75")
      end
    end

    context 'with an allocation snapshot' do
      let(:allocation) do
        double(
          'SpreeVietqr::PaymentAllocation',
          bank_bin: '970436',
          account_number: '111222333',
          account_name: 'ALLOCATED ACCOUNT',
          expected_amount: 222_000,
          transfer_content: 'MMOR123456789',
          provider_qr_code: nil
        )
      end

      it 'uses the allocation account and amount' do
        url = subject.call(payment_method: payment_method, order: order, allocation: allocation)

        expect(url).to include('img.vietqr.io/image/970436-111222333-compact2.png')
        expect(url).to include('amount=222000')
        expect(url).to include('accountName=ALLOCATED+ACCOUNT')
      end
    end

    context 'for topup with a receiving account' do
      let(:receiving_account) do
        double(
          'SpreeVietqr::ReceivingAccount',
          bank_bin: '970436',
          account_number: '444555666',
          account_name: 'TOPUP ACCOUNT'
        )
      end

      it 'uses the receiving account for the QR destination' do
        url = subject.call_for_topup(
          payment_method: payment_method,
          amount: 100_000,
          transfer_content: 'DHNAPABC12345',
          receiving_account: receiving_account
        )

        expect(url).to include('img.vietqr.io/image/970436-444555666-compact2.png')
        expect(url).to include('amount=100000')
        expect(url).to include('addInfo=DHNAPABC12345')
        expect(url).to include('accountName=TOPUP+ACCOUNT')
      end
    end
  end
end
