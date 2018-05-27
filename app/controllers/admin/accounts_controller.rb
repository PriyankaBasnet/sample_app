class Api::Admin::AccountsController < AdminController
  before_action :setup, only: [:update]
  skip_before_action :authorize_user_for_account!, only: [:create]

  def update
    @account.domains = format_domains if format_domains.present?
    @account.profane_words = params[:profane_words].split(",") unless params[:profane_words].nil?
    @account.comments_limit = params[:comments_limit] if params[:comments_limit].present?
    @account.update_configurations(params[:configurations].as_json) if params[:configurations].present?

    if params[:sso_redirect_uri].present?
      oauth_app = @account.oauth_application
      oauth_app.redirect_uri = params[:sso_redirect_uri]
      oauth_app.save!
    end

    if params[:profanity_configuration].present?
      if validate_profanity_configuration?(params[:profanity_configuration])
        @account.update_profanity_configuration(params[:profanity_configuration])
      else
        render status: 422, json: {error: {message: "Invalid profanity_configuration"}}
      end
    end
    @account.save!
  end

  def create
    params.require([:account_name, :account_email, :website_url])
    if params[:razorpay_subscription_id]
      razorpay_subscription = Subscription.find_in_razorpay(params[:razorpay_subscription_id])
      metype_subscription = Subscription.find_by(razorpay_subscription_id: params[:razorpay_subscription_id])
      if razorpay_subscription["status"] == "active" && metype_subscription
        account = current_user.create_account(name: params[:account_name], email_id: params[:account_email], website_url: params[:website_url], domains: params[:website_url])
        if metype_subscription
          metype_subscription.payment_id = params[:razorpay_payment_id]
          metype_subscription.account_id = account.id
          metype_subscription.save!
        end
      end
    else
      params.require(:subscription_id)
      subscription = Subscription.find_by_id(params[:subscription_id])
      if subscription.present?
         account = current_user.create_account(name: params[:account_name], email_id: params[:account_email], website_url: params[:website_url], domains: params[:website_url])
         subscription.account_id = account.id
         subscription.save!
      end
    end
  end

  private
  def format_domains
    if params["domains"].present?
      params["domains"].split(",").map do |domain|
        stripped_domain = domain.strip
        if uri? stripped_domain
          stripped_domain
        end
      end.compact
    end
  end

  def authorize_user_for_account!
    render status: :unauthorized, :nothing => true unless current_user.authorized?(params[:id])
  end

  def setup
    begin
      @account = Account.find(params[:id])
    rescue ActiveRecord::RecordNotFound => e
      render status: :not_found, json: {error: e.message}
    end
  end

  private
  def validate_profanity_configuration?(profanity_configuration)
    profanity_configuration.keys.all? do |profanity_configuration_key|
      ["manage_sensitive_content", "pre_moderate_profane_comment"].include? profanity_configuration_key
    end
  end
end
