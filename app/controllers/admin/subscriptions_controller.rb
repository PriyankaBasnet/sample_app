class Api::Admin::SubscriptionsController < AdminController
  skip_before_action :authorize_user_for_account!

  def create
    current_user.register_with_razorpay
    if params[:plan_id]
      plan = Plan.find(params[:plan_id])
      subscription = Subscription.new_subscription(current_user, plan)
    else
      subscription = Subscription.new_subscription(current_user)
    end
    respond_with(subscription, location: nil)
  end
end
