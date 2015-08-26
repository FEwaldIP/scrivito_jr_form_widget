class CrmFormAttributes
  include ActiveModel::Model

  attr_accessor :custom_first_name, :custom_last_name, :custom_email, :custom_zip, :custom_request, :custom_phone, :first_name, :last_name, :email, :zip, :request, :phone

end