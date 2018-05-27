require_relative "../../../jobs/submit_comment_to_akismet"

class Api::Admin::CommentsController < AdminController
  before_action :load_account

  def load_account
    begin
      @account = Account.find(params[:account_id])
    rescue ActiveRecord::RecordNotFound => e
      render status: :not_found, json: {error: e.message}
    end
  end

  def index
    begin
      opts = {
        order_by: params[:order_by]&.to_sym || :created_at,
        sort_order: params[:sort_order] || "desc",
        page: params[:page] || 1,
        per_page: params[:per_page] || 10,
        status: params[:status],
        q: params[:mquery],
        filters: valid_filters(params[:filters])
      }

      comments = @account.list_comments(opts)

      render status: :ok, json: {
               comments: comments.as_json(show_deleted_comments?: true),
               total_entries: comments.total_entries,
               total_pages: comments.total_pages
             }
    rescue Exception => e
      Rails.logger.error e
      render status: :unprocessable_entity, json: {error: {message: e.message}}
    end

    set_surrogate_key_header @account.record_key
  end

  def delete
    begin
      @comments = @account.comments.where(id: params[:comment_ids])
      @comments.map {|comment|
        comment.soft_delete current_user
        comment.save!
      } unless @comments.empty?
      Comment.search_index.refresh
      render json: {comment: @comments}
    rescue Exception => e
      Rails.logger.error e
      render status: :unprocessable_entity, json: {error: {message: e.message}}
    end
  end

  def restore
    begin
      @comments = @account.comments.where(id: params[:comment_ids])
      @comments.map do |comment|
        if authorize_user_for_comment(comment)
          comment.undo_soft_delete
          comment.save!
        end
      end unless @comments.empty?
      Comment.search_index.refresh
      render json: {comment: @comments}
    rescue Exception => e
      Rails.logger.error e
      render status: :unprocessable_entity, json: {error: {message: e.message}}
    end
  end

  def approve
    begin
      if current_user
        @comments = @account.comments.where(id: params[:comment_ids])
        @comments.map do |comment|
          if authorize_user_for_comment(comment)
            SubmitCommentToAkisment.perform_later(comment, "ham") if comment.is_spam
            comment.approve(current_user.id)
            comment.save!
          end
        end unless @comments.empty?
        Comment.search_index.refresh
        render json: {comment: @comments}
      end
    rescue Exception => e
      Rails.logger.error e
      render status: :unprocessable_entity, json: {error: {message: e.message}}
    end
  end

  def spam
    begin
      if current_user
        @comments = @account.comments.where(id: params[:comment_ids])
        @comments.map do |comment|
          SubmitCommentToAkisment.perform_later(comment, "spam")
          comment.mark_spam_by_user(current_user.id)
          comment.save!
        end unless @comments.empty?
        Comment.search_index.refresh
        render json: {comment: @comments}
      end
    rescue Exception => e
      Rails.logger.error e
      render status: :unprocessable_entity, json: {error: {message: e.message}}
    end
  end

  def show
    @comment = Comment.find(params[:id])
    render json: { comment: @comment , timeline: @comment.timeline }
  end

  private
  def authorize_user_for_comment(comment)
    (comment.author?(current_user) && comment.hidden?) || !comment.hidden?
  end

  def whitelisted_filters
    [:flagged]
  end

  def whitelisted_reactions
    {flagged: "Flag"}
  end

  def valid_filters(filters)
    if filters.present?
      filters.as_json.inject({}) do |hash, (k,v)|
        if whitelisted_filters.include?(k.to_sym)
          if reaction_name = whitelisted_reactions[k.to_sym]
            hash[Reaction.find_by_name(reaction_name).id] = v == "true" && v ? true : false
          else
            hash[k] = v
          end
        end
        hash
      end
    end
  end
end
