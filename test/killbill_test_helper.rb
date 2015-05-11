module Kaui
  module KillbillTestHelper

    USERNAME = 'admin'
    PASSWORD = 'password'

    #
    # Rails helpers
    #

    def check_no_flash_error
      unless flash.now.nil?
        assert_nil flash.now[:alert], 'Found flash alert: ' + flash.now[:alert].to_s
        assert_nil flash.now[:error], 'Found flash error: ' + flash.now[:error].to_s
      end
      assert_nil flash[:alert]
      assert_nil flash[:error]
    end

    #
    # Kill Bill specific helpers
    #

    def setup_test_data(nb_configured_tenants =  1, setup_tenant_key_secret = true)
      @tenant            = setup_and_create_test_tenant(nb_configured_tenants)
      @account           = create_account(@tenant)
      @account2          = create_account(@tenant)
      @bundle            = create_bundle(@account, @tenant)
      @invoice_item      = create_charge(@account, @tenant)
      @paid_invoice_item = create_charge(@account, @tenant)
      @bundle_invoice    = @account.invoices(true, build_options(@tenant)).first
      @payment_method    = create_payment_method(true, @account, @tenant)
      @cba               = create_cba(@invoice_item.invoice_id, @account, @tenant)
      @payment           = create_payment(@paid_invoice_item, @account, @tenant)

      if setup_tenant_key_secret
        KillBillClient.api_key = @tenant.api_key
        KillBillClient.api_secret = @tenant.api_secret
      else
        KillBillClient.api_key = nil
        KillBillClient.api_secret = nil
      end
      KillBillClient.username = USERNAME
      KillBillClient.password = PASSWORD
      @tenant
    end

    def setup_and_create_test_tenant(nb_configured_tenants)

      # If we need to configure 0 tenant, we still create one with Kill Bill but add nothing in the kaui_tenants and kaui_allowed_users tables
      if nb_configured_tenants == 0
        return create_tenant
      end

      # Setup AllowedUser
      au = Kaui::AllowedUser
        .find_or_create_by(kb_username: 'admin', description: 'Admin User')

      # Create the tenant with Kill Bill
      all_tenants = []
      test_tenant = nil
      (1..nb_configured_tenants).each do |i|
        cur_tenant = create_tenant
        test_tenant = cur_tenant if test_tenant.nil?

        t = Kaui::Tenant.new
        t.kb_tenant_id = cur_tenant.tenant_id
        t.name = 'Test'
        t.api_key = cur_tenant.api_key
        t.api_secret = cur_tenant.api_secret
        t.save
        all_tenants << t
      end

      # setup kaui_tenants
      all_tenants.each { |e| au.kaui_tenants  << e } if all_tenants.size > 0
      test_tenant
    end

    # Return a new test account
    def create_account(tenant = nil, username = USERNAME, password = PASSWORD, user = 'Kaui test', reason = nil, comment = nil)
      tenant       = create_tenant if tenant.nil?
      external_key = SecureRandom.uuid.to_s

      account                          = KillBillClient::Model::Account.new
      account.name                     = 'Kaui'
      account.external_key             = external_key
      account.email                    = 'kill@bill.com'
      account.currency                 = 'USD'
      account.time_zone                = 'UTC'
      account.address1                 = '5, ruby road'
      account.address2                 = 'Apt 4'
      account.postal_code              = 10293
      account.company                  = 'KillBill, Inc.'
      account.city                     = 'SnakeCase'
      account.state                    = 'Awesome'
      account.country                  = 'LalaLand'
      account.locale                   = 'fr_FR'
      account.is_notified_for_invoices = false

      account.create(user, reason, comment, build_options(tenant, username, password))
    end

    # Return the created bundle
    def create_bundle(account = nil, tenant = nil, username = USERNAME, password = PASSWORD, user = 'Kaui test', reason = nil, comment = nil)
      tenant  = create_tenant(user, reason, comment) if tenant.nil?
      account = create_account(tenant, username, password, user, reason, comment) if account.nil?

      entitlement = KillBillClient::Model::Subscription.new(:account_id       => account.account_id,
                                                            :external_key     => SecureRandom.uuid,
                                                            :product_name     => 'Sports', # Sports, so we can add addons
                                                            :product_category => 'BASE',
                                                            :billing_period   => 'MONTHLY',
                                                            :price_list       => 'DEFAULT')
      entitlement = entitlement.create(user, reason, comment, build_options(tenant, username, password))

      KillBillClient::Model::Bundle.find_by_id(entitlement.bundle_id, build_options(tenant, username, password))
    end

    # Return a new test payment method
    def create_payment_method(set_default = false, account = nil, tenant = nil, username = USERNAME, password = PASSWORD, user = 'Kaui test', reason = nil, comment = nil)
      account = create_account(tenant, username, password, user, reason, comment) if account.nil?

      payment_method = Kaui::PaymentMethod.new(:account_id => account.account_id, :plugin_name => '__EXTERNAL_PAYMENT__', :is_default => set_default)
      payment_method.create(true, user, reason, comment, build_options(tenant, username, password))
    end

    # Return the created external charge
    def create_charge(account = nil, tenant = nil, username = USERNAME, password = PASSWORD, user = 'Kaui test', reason = nil, comment = nil)
      tenant  = create_tenant(user, reason, comment) if tenant.nil?
      account = create_account(tenant, username, password, user, reason, comment) if account.nil?

      invoice_item            = KillBillClient::Model::InvoiceItem.new
      invoice_item.account_id = account.account_id
      invoice_item.currency   = account.currency
      invoice_item.amount     = 123.98

      invoice_item.create(user, reason, comment, build_options(tenant, username, password))
    rescue
      nil
    end

    # Return the created credit
    def create_cba(invoice_id = nil, account = nil, tenant = nil, username = USERNAME, password = PASSWORD, user = 'Kaui test', reason = nil, comment = nil)
      tenant  = create_tenant(user, reason, comment) if tenant.nil?
      account = create_account(tenant, username, password, user, reason, comment) if account.nil?

      credit = KillBillClient::Model::Credit.new(:invoice_id => invoice_id, :account_id => account.account_id, :credit_amount => 23.22)
      credit = credit.create(user, reason, comment, build_options(tenant, username, password))

      invoice = KillBillClient::Model::Invoice.find_by_id_or_number(credit.invoice_id, true, 'NONE', build_options(tenant, username, password))
      invoice.items.find { |ii| ii.amount == -credit.credit_amount }
    end

    def create_payment(invoice_item = nil, account = nil, tenant = nil, username = USERNAME, password = PASSWORD, user = 'Kaui test', reason = nil, comment = nil)
      tenant       = create_tenant(user, reason, comment) if tenant.nil?
      account      = create_account(tenant, username, password, user, reason, comment) if account.nil?
      invoice_item = create_charge(account, tenant, username, password, user, reason, comment) if invoice_item.nil?

      payment = Kaui::InvoicePayment.new({:account_id => account.account_id, :target_invoice_id => invoice_item.invoice_id, :purchased_amount => invoice_item.amount})
      payment.create(true, user, reason, comment, build_options(tenant, username, password))
    end

    # Return a new test tenant
    def create_tenant(user = 'Kaui test', reason = nil, comment = nil)
      api_key    = SecureRandom.uuid.to_s
      api_secret = 'S4cr3333333t!!!!!!lolz'

      tenant            = KillBillClient::Model::Tenant.new
      tenant.api_key    = api_key
      tenant.api_secret = api_secret

      tenant = tenant.create(user, reason, comment, build_options)

      # Re-hydrate the secret, which is not returned
      tenant.api_secret = api_secret

      tenant
    end

    def build_options(tenant = nil, username = USERNAME, password = PASSWORD)
      {
          :api_key    => tenant.nil? ? nil : tenant.api_key,
          :api_secret => tenant.nil? ? nil : tenant.api_secret,
          :username   => username,
          :password   => password
      }
    end

    def options
      build_options(@tenant)
    end
  end
end
