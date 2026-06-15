class Public::PostsController < ApplicationController
  # =========================
  # アクセス制御
  # =========================

  # 投稿一覧(index)と投稿詳細(show)は、未ログインユーザーでも閲覧できるようにする
  # 例：サービスを初めて見に来た人でも投稿一覧や詳細を確認できるようにするため
  allow_unauthenticated_access only: %i[index show]

  # show / edit / update / destroy では、対象となる投稿データが必要になる
  # 各アクション内で毎回 Post.find を書くと重複するため、before_actionで共通化している
  before_action :set_post, only: %i[show edit update destroy]

  # 投稿の編集・更新・削除は、投稿した本人だけができるように制限する
  # 他人の投稿を勝手に編集・削除されないようにするための権限チェック
  before_action :ensure_correct_user, only: %i[edit update destroy]

  # =========================
  # 投稿一覧
  # =========================

  def index
    # 投稿一覧画面でタグ検索・タグ表示に使うため、タグ一覧を名前順で取得する
    @tags = Tag.order(:name)

    # 並び替え条件を画面側で保持するために取得する
    # 例：新着順、いいね順、コメント順など
    @sort = params[:sort]

    # 期間指定の条件を画面側で保持するために取得する
    # 例：今日、今週、今月など
    @period = params[:period]

    # 表示モードを取得する
    # params[:mode] がない場合は "all" を初期値にする
    # 例：全体投稿、フォロー中ユーザーの投稿などを切り替えるため
    @mode = params[:mode] || "all"

    # 投稿の検索・絞り込み・並び替え処理は PostSearchQuery に切り出している
    # Controllerに検索条件を直接たくさん書くと複雑になるため、
    # Query Objectとして分離し、Controllerを読みやすくしている
    @posts = PostSearchQuery.new(
      params: params,                 # 検索条件・並び替え条件などを渡す
      current_user: current_user,     # ログイン中ユーザーを渡す
      authenticated: authenticated?   # ログイン状態を渡す
    ).call
     .page(params[:page])             # kaminariでページネーションする
     .per(10)                         # 1ページあたり10件表示する
  end

  # =========================
  # 投稿詳細
  # =========================

  def show
    # 下書き投稿は、投稿者本人だけが閲覧できるようにする
    # 未ログインユーザーや他のユーザーがURLを直接入力しても見られないようにするため
    if @post.draft? && (!authenticated? || @post.user != current_user)
      redirect_to posts_path, alert: t("flash.alert.cannot_view_post")
      return
    end

    # コメント投稿フォームで使用する空のCommentインスタンスを用意する
    @comment = Comment.new

    # 投稿に紐づくコメント一覧を取得する
    # includes(:user) により、コメント投稿者の情報をまとめて取得し、N+1問題を防ぐ
    # order(created_at: :desc) で新しいコメントから表示する
    @comments = @post.comments.includes(:user).order(created_at: :desc)
  end

  # =========================
  # 投稿作成画面
  # =========================

  def new
    # 新規投稿フォームで使用する空のPostインスタンスを用意する
    @post = Post.new
  end

  # =========================
  # 投稿作成処理
  # =========================

  def create
    # ログイン中ユーザーに紐づけて投稿を作成する
    # current_user.posts.build とすることで、
    # user_id をフォームから送らせず、サーバー側で安全に設定できる
    @post = current_user.posts.build(post_params)

    if @post.save
      # 投稿保存後に、フォームから受け取ったタグ文字列を分解して関連付ける
      # 投稿IDが必要になるため、投稿を保存した後にタグを保存している
      @post.save_tags(post_params[:tag_names])

      # 下書き保存か公開投稿かによって、表示するフラッシュメッセージを切り替える
      redirect_to post_path(@post),
                  notice: @post.draft? ? t("flash.notice.draft_saved") : t("flash.notice.post_created")
    else
      # バリデーションエラー時は、投稿作成画面を再表示する
      # flash.now は render 時にだけ表示するフラッシュメッセージ
      flash.now[:alert] = t("flash.alert.post_failed")

      # render を使うことで、入力値やエラー情報を保持したまま new 画面を表示できる
      # status: :unprocessable_entity は、入力内容に問題があることをHTTPステータスで表す
      render :new, status: :unprocessable_entity
    end
  end

  # =========================
  # 投稿更新処理
  # =========================

  def update
    # 対象投稿をフォームから送られた値で更新する
    # 更新対象の投稿は before_action の set_post で取得済み
    if @post.update(post_params)
      # 投稿内容の更新後に、タグも更新する
      # タグは投稿本体とは別の関連データなので、save_tagsで別途処理している
      @post.save_tags(post_params[:tag_names])

      # 下書き更新か公開投稿の更新かによって、メッセージを切り替える
      redirect_to post_path(@post),
                  notice: @post.draft? ? t("flash.notice.draft_updated") : t("flash.notice.post_updated")
    else
      # バリデーションエラー時は、編集画面を再表示する
      flash.now[:alert] = t("flash.alert.update_failed")

      # redirect_to ではなく render を使うことで、
      # 入力内容とエラーメッセージを保持したまま edit 画面を表示できる
      render :edit, status: :unprocessable_entity
    end
  end

  # =========================
  # 投稿削除処理
  # =========================

  def destroy
    # 対象投稿を削除する
    # dependent: :destroy がモデルに設定されていれば、
    # 投稿に紐づくコメント・いいね・タグ関連なども適切に削除される
    @post.destroy

    # 削除後は投稿一覧へ遷移する
    redirect_to posts_path, notice: t("flash.notice.post_deleted")
  end

  private

  # =========================
  # 共通処理
  # =========================

  def set_post
    # URLの :id パラメータを使って対象投稿を取得する
    # 例：/posts/1 の場合、params[:id] は 1 になる
    @post = Post.find(params[:id])
  end

  def post_params
    # Strong Parameters
    # フォームから送られてきた値のうち、許可した項目だけを受け取る
    # これにより、user_id や admin権限など、意図しない値の書き換えを防ぐ
    params.require(:post).permit(
      :title,              # 投稿タイトル
      :body,               # 投稿本文
      :study_time_hour,    # 学習時間の「時間」部分
      :study_time_minute,  # 学習時間の「分」部分
      :tag_names,          # タグ名の文字列
      :status              # 公開・下書きなどの投稿ステータス
    )
  end

  def ensure_correct_user
    # 投稿者本人であれば処理を続行する
    # @post.user は投稿者、current_user は現在ログイン中のユーザー
    return if @post.user == current_user

    # 投稿者本人でない場合は、投稿一覧へ戻す
    # これにより、他人の投稿編集・更新・削除を防ぐ
    redirect_to posts_path, alert: t("flash.alert.unauthorized")
  end
end
