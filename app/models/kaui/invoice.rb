require 'active_model'

class Kaui::Invoice < Kaui::Base
  define_attr :amount
  define_attr :balance
  define_attr :invoice_id
  define_attr :account_id
  define_attr :invoice_number
  define_attr :payment_amount
  define_attr :refund_adjustment
  define_attr :credit_balance_adjustment
  define_attr :credit_adjustment
  define_attr :invoice_dt
  define_attr :payment_dt
  define_attr :target_dt
  define_attr :bundle_keys
  has_many :items, Kaui::InvoiceItem

  def initialize(data = {})
    super(
          :account_id => data['accountId'],
          :amount => data['amount'],
          :balance => data['balance'],
          :credit_balance_adjustment => data['cba'],
          :credit_adjustment => data['creditAdj'],
          :invoice_dt => data['invoiceDate'],
          :invoice_id => data['invoiceId'],
          :invoice_number => data['invoiceNumber'],
          :refund_adjustment => data['refundAdj'],
          :target_dt => data['targetDate'],
          :items => data['items'],
          :bundle_keys => data['bundleKeys'])
  end
end