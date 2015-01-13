module Kaui
  class Tenant < ActiveRecord::Base
    attr_accessible :name, :api_key, :api_secret, :kb_tenant_id

    has_many :kaui_users, {
        :class_name => 'Kaui::User',
        :primary_key => 'kb_tenant_id',
        :foreign_key => 'kb_tenant_id'}

    has_many :kaui_allowed_users_tenants, :class_name => 'Kaui::AllowedUserTenant', :foreign_key => 'kaui_tenant_id'
    has_many :kaui_allowed_users, :through => :kaui_allowed_users_tenants, :source => :kaui_allowed_user

  end
end
