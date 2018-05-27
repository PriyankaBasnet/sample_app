class Api::Admin::CurrentUsersController < AdminController
  respond_to :json
  skip_before_action :authenticate_user!
  skip_before_action :authorize_user_for_account!

  def show
    if user_signed_in?
      provider = Authentication.where(user_id: current_user['id']).pluck(:provider).first
      render status: 200, json: {current_user: current_user.as_json(admin_details: true),
                                 is_guest: current_user.guest,
                                 provider: provider}
    else
      render status: 403, json: {signed_in: false, is_guest: true }
    end
  end

  def destroy
    session.delete("fb_expiry")
    session.delete("fb_access_token")
    success = sign_out(:user)
    render :json => { :success => success.as_json }
  end

  def update
    params.require(:user)
    authorize! :update, current_user
    location = nil
    location = Location.find_or_create_by(
      full_address: params[:user][:location][:full_address],
      latitude: params[:user][:location][:latitude],
      longitude: params[:user][:location][:longitude]
    ) if params[:user][:location]
    fields = {}
    fields.merge!(bio: params[:user][:bio]) if params[:user][:bio]
    fields.merge!(avatar: S3.move_image_to_permanent_bucket(params[:user][:avatar])) if params[:user][:avatar]
    fields.merge!(public_fields: params[:user][:public_fields]) if params[:user][:public_fields]
    fields.merge!(location: location) if location
    current_user.update(fields)
    if current_user.save!
      render status: :created, json: { current_user: current_user }
    else
      render status: :unprocessible_entity, json: {
        error: {
          message: 'Could Not Update'
        }
      }
    end
  end
end
