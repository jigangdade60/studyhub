class Public::CommentsController < ApplicationController
  # コメントの作成・削除は、必ず特定の投稿に対して行う
  # そのため create / destroy の前に、対象となる投稿を取得しておく
  before_action :set_post, only: %i[create destroy]

  # =========================
  # コメント作成処理
  # =========================
  def create
    # @post.comments.build を使うことで、
    # 「どの投稿に対するコメントなのか」を明確に紐づけている
    #
    # Comment.new(comment_params) でもコメント自体は作れるが、
    # post_id を自分で設定する必要があるため、
    # 関連を使って build した方が安全でRailsらしい書き方になる
    @comment = @post.comments.build(comment_params)

    # コメント投稿者はフォームから送らせず、
    # ログイン中のユーザー current_user を使ってサーバー側で設定する
    #
    # 理由：
    # フォームから user_id を受け取ると、
    # 悪意あるユーザーが別ユーザーのIDを送信して
    # なりすましコメントを作成できてしまうため
    @comment.user = current_user

    # コメントの保存を実行する
    # バリデーションに成功すれば true、失敗すれば false が返る
    if @comment.save
      # 保存に成功した場合は、投稿詳細画面へリダイレクトする
      #
      # redirect_to を使う理由：
      # コメント投稿後にブラウザを更新したとき、
      # 同じPOSTリクエストが再送信されて
      # コメントが二重投稿されるのを防ぐため
      #
      # notice には、i18nで管理している成功メッセージを表示する
      redirect_to post_path(@post), notice: t("flash.notice.comment_created")
    else
      # 保存に失敗した場合は、投稿詳細画面を再表示する
      #
      # 例：
      # ・コメント本文が空
      # ・文字数制限を超えている
      #
      # render で posts/show を表示するため、
      # show画面で必要な @comments などのデータを再取得する必要がある
      set_view_resources

      # render は別アクションへ移動するのではなく、
      # 指定したビューをその場で表示する処理
      #
      # status: :unprocessable_entity はHTTPステータス422を返す指定
      # 「リクエストの形式は正しいが、バリデーションエラーで処理できなかった」
      # という意味になる
      render "public/posts/show", status: :unprocessable_entity
    end
  end

  # =========================
  # コメント削除処理
  # =========================
  def destroy
    # current_user.comments.find(params[:id]) とすることで、
    # ログイン中ユーザーが投稿したコメントの中から対象コメントを探す
    #
    # これにより、他人のコメントIDをURLに直接入力しても
    # 自分のコメントではないため取得できず、削除できない
    #
    # Comment.find(params[:id]) とすると、
    # 他人のコメントも取得できてしまう可能性があるため危険
    @comment = current_user.comments.find(params[:id])

    # 対象コメントを削除する
    # モデル側に dependent: :destroy などがあれば、
    # 関連データも必要に応じて削除される
    @comment.destroy

    # 削除後は、元の投稿詳細画面へ戻す
    #
    # redirect_to を使うことで、
    # 削除処理後に再読み込みしてもDELETEリクエストが再送信されにくくなる
    redirect_to post_path(@post), notice: t("flash.notice.comment_deleted")
  end

  private

  # =========================
  # 対象投稿の取得
  # =========================
  def set_post
    # comments は posts にネストされたルーティングになっているため、
    # URLには params[:post_id] が含まれる
    #
    # 例：
    # POST /posts/1/comments
    # DELETE /posts/1/comments/5
    #
    # この post_id を使って、コメント対象の投稿を取得する
    @post = Post.find(params[:post_id])
  end

  # =========================
  # 投稿詳細画面の再表示に必要なデータを取得
  # =========================
  def set_view_resources
    # コメント保存に失敗した場合、
    # render "public/posts/show" で投稿詳細画面を再表示する
    #
    # その際、show画面で @comments を使っているため、
    # ここで再取得しておく必要がある
    #
    # includes(:user) を使うことで、
    # コメント一覧で comment.user を表示するときのN+1問題を防ぐ
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end

  # =========================
  # Strong Parameters
  # =========================
  def comment_params
    # フォームから送られてきた comment パラメータのうち、
    # body のみを許可する
    #
    # user_id や post_id は外部から受け取らず、
    # サーバー側で current_user や @post から設定する
    #
    # これにより、不正な値の書き換えを防ぐ
    params.require(:comment).permit(:body)
  end
end