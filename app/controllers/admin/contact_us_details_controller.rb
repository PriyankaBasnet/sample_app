class Api::Admin::ContactUsDetailsController < ApiController
  def create
    ContactUsDetail.create!(name: params['contact_us']['name'],
                            email: params['contact_us']['email'],
                            message: params['contact_us']['message'],
                            company: params['contact_us']['company_name'],
                            phone_no: params['contact_us']['mobile_number'])
  end
end
