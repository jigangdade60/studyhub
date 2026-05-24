class PostSearchQuery
  def initialize(params:, current_user: nil, authenticated: false)
    @params = params
    @current_user = current_user
    @authenticated = authenticated
  end

  def call
    posts = base_posts
    posts = filter_following(posts)
    posts = filter_posts(posts)
    sort_posts(posts)
  end

  private

  attr_reader :params, :current_user, :authenticated

  def base_posts
    if authenticated && current_user.present?
      # ログイン中は公開投稿に加えて、自分の下書きも一覧に含める
      Post.includes(:user, :tags, :likes, :comments)
          .where("posts.status = ? OR posts.user_id = ?", Post.statuses[:published], current_user.id)
    else
      # 未ログイン時は公開投稿のみ表示する
      Post.includes(:user, :tags, :likes, :comments)
          .where(status: :published)
    end
  end

  def filter_following(posts)
    return posts unless mode == "following"

    if authenticated && current_user.present?
      posts.where(user_id: current_user.following_ids)
    else
      Post.none
    end
  end

  def filter_posts(posts)
    posts
      .keyword_search(params[:keyword])
      .tag_search(params[:tag_name])
      .period_search(params[:period])
      .distinct
  end

  def sort_posts(posts)
    case sort
    when "old"
      posts.order(created_at: :asc)
    when "likes"
      posts.order(likes_count: :desc, created_at: :desc)
    when "comments"
      posts.order(comments_count: :desc, created_at: :desc)
    else
      posts.order(created_at: :desc)
    end
  end

  def sort
    params[:sort]
  end

  def mode
    params[:mode] || "all"
  end
end
