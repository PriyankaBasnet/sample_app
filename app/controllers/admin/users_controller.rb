class Api::Admin::UsersController < AdminController

  before_action :load_account

  def load_account
    begin
      @account = Account.find(params[:account_id])
    rescue ActiveRecord::RecordNotFound => e
      render status: :not_found, json: {error: e.message}
    end
  end


  def index
    if params[:search].present?
      search_users
    else
      list_users
    end
  end

  def create
    AccountUser.find_or_create_by( {account_id: params[:account_id].to_i, user_id: params[:user_id].to_i, added_by_user_id: current_user.id })
    render json: AccountUser.where(account_id: @account.id)
  end

  def destroy
    if params.has_key?(:ban)
      ban_unban_user
    else
      account_user = AccountUser.find_by({ account_id: params[:account_id].to_i, user_id: params[:id].to_i })
      if account_user
        account_user.delete
        render json: AccountUser.where(account_id: @account.id)
      end
    end
  end

  private

  def ban_unban_user
    if params[:ban]
      User.ban(params[:account_id], params[:id], current_user.id )
      render json: @account.banned_users
    else
      User.unban(params[:account_id], params[:id])
      render json: @account.banned_users
    end
  end

  def search_users
    if params[:q_account_user]
      query_account_users
    elsif params[:q_banned_user]
      query_banned_users
    end
  end

  def query_account_users
    account_user_ids = @account.user_ids
    users_limit = params[:limit].to_i || 5
    q_term = "#{params[:q_account_user]}%"
    users = User.query_account_users(account_user_ids, q_term, users_limit)
    render json: { users: users }
  end

  def query_banned_users
    banned_user_ids = @account.banned_users.map(&:user_id)
    users_limit = params[:limit].to_i || 5
    q_term = "#{params[:q_banned_user]}%"
    users = User.query_banned_users(banned_user_ids, q_term, users_limit)
    render json: { users: users }
  end

  def list_users
    if params[:account_users]
      render json: @account.account_users
    elsif params[:banned_users]
      render json: @account.banned_users
    end
  end

end
