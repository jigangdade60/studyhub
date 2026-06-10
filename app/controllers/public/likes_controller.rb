module Public
  class LikesController < ApplicationController
    # =========================
    # 認証チェック
    # =========================

    # いいね機能は「誰がいいねしたか」を記録する必要があるため、
    # 未ログインユーザーには利用させない
    before_action :require_authentication

    # =========================
    # いいね一覧
    # =========================

    def index
      # current_user.liked_posts により、
      # ログイン中ユーザーがいいねした投稿だけを取得する
      #
      # liked_posts は Userモデル側で
      # has_many :liked_posts, through: :likes, source: :post
      # のように定義している想定
      @liked_posts = current_user.liked_posts
                 # 投稿者のプロフィール画像を一緒に読み込む
                 # これにより、一覧表示時に投稿ごとに画像取得SQLが発生する
                 # N+1問題を防ぐ
                 .includes(user: { profile_image_attachment: :blob })

                 # 新しく作成された投稿順に並べる
                 # いいねした順ではなく、投稿の作成日時順で表示している
                 .order(created_at: :desc)

      # kaminari によるページネーション
      # 1ページあたり10件ずつ表示する
      @liked_posts = @liked_posts.page(params[:page]).per(10)
    end

    # =========================
    # いいね作成
    # =========================

    def create
      # URLパラメータの post_id から、
      # いいね対象の投稿を取得する
      @post = Post.find(params[:post_id])

      # 対象投稿に対して、ログイン中ユーザーのいいねを作成する
      #
      # find_or_create_by! を使うことで、
      # すでに同じユーザーが同じ投稿にいいねしている場合は既存レコードを取得し、
      # まだ存在しない場合だけ新規作成する
      #
      # これにより、同じ投稿への重複いいねを防ぐ
      @post.likes.find_or_create_by!(user: current_user)

      respond_to do |format|
        # HTMLリクエストの場合
        # 通常の画面遷移として、直前のページへ戻す
        #
        # redirect_back は戻り先がない場合にエラーになる可能性があるため、
        # fallback_location で posts_path を指定している
        format.html do
          redirect_back fallback_location: posts_path,
                        notice: t("flash.notice.like")
        end

        # Turbo Streamリクエストの場合
        # ページ全体をリロードせず、いいねボタンや件数部分だけを更新する
        #
        # 対応する create.turbo_stream.erb が呼ばれる想定
        format.turbo_stream
      end
    end

    # =========================
    # いいね削除
    # =========================

    def destroy
      # URLパラメータの post_id から、
      # いいね解除対象の投稿を取得する
      @post = Post.find(params[:post_id])

      # 対象投稿に紐づくいいねの中から、
      # ログイン中ユーザー自身のいいねだけを取得する
      #
      # current_user を条件にしているため、
      # 他人のいいねを削除できないようになっている
      like = @post.likes.find_by(user: current_user)

      # いいねが存在する場合のみ削除する
      #
      # &. は safe navigation operator で、
      # like が nil の場合でもエラーにせず何もしない
      like&.destroy

      respond_to do |format|
        # HTMLリクエストの場合
        # 通常の画面遷移として、直前のページへ戻す
        format.html do
          redirect_back fallback_location: posts_path,
                        notice: t("flash.notice.unlike")
        end

        # Turbo Streamリクエストの場合
        # ページ全体を更新せず、いいねボタンや件数部分だけを差し替える
        #
        # 対応する destroy.turbo_stream.erb が呼ばれる想定
        format.turbo_stream
      end
    end
  end
end