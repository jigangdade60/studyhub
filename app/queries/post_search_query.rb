# 投稿一覧の検索・絞り込み・並び替えをまとめるためのクラス
# Controllerに検索条件や並び替え処理を直接書くと複雑になるため、
# Query Objectとして切り出している
class PostSearchQuery
  # 検索条件としてparamsを受け取る
  # current_userはログイン中のユーザー
  # authenticatedはログインしているかどうかを判定するための値
  def initialize(params:, current_user: nil, authenticated: false)
    @params = params
    @current_user = current_user
    @authenticated = authenticated
  end

  # 外部から呼び出すメインメソッド
  # 投稿の取得 → フォロー中の絞り込み → 検索条件で絞り込み → 並び替え
  # という流れで投稿一覧を作成する
  def call
    # まず、ログイン状態に応じて表示対象の投稿を取得する
    posts = base_posts

    # modeがfollowingの場合は、フォロー中ユーザーの投稿だけに絞る
    posts = filter_following(posts)

    # キーワード、タグ、期間で投稿を絞り込む
    posts = filter_posts(posts)

    # 最後に、指定された条件で並び替える
    sort_posts(posts)
  end

  private

  # このクラス内だけで使う値
  attr_reader :params, :current_user, :authenticated

  # 投稿一覧の元になるデータを取得するメソッド
  def base_posts
    if authenticated && current_user.present?
      # ログイン中は、公開投稿に加えて自分の下書きも一覧に含める
      # 他人の下書きは表示しない
      #
      # includesで関連データをまとめて読み込む
      # tags、likes、comments、user、プロフィール画像を事前に取得し、
      # 投稿一覧画面でN+1問題が起きないようにしている
      #
      # user: { profile_image_attachment: :blob } は、
      # ActiveStorageで管理しているプロフィール画像をプリロードする指定
      Post.includes(:tags, :likes, :comments, user: { profile_image_attachment: :blob })
          .where(
            "posts.status = ? OR posts.user_id = ?",
            Post.statuses[:published],
            current_user.id
          )
    else
      # 未ログイン時は公開投稿のみ表示する
      # 下書き投稿は表示しない
      #
      # こちらも一覧表示で使う関連データをincludesで先に読み込み、
      # N+1問題を防いでいる
      Post.includes(:tags, :likes, :comments, user: { profile_image_attachment: :blob })
          .where(status: :published)
    end
  end

  # フォロー中ユーザーの投稿だけに絞り込むメソッド
  def filter_following(posts)
    # modeがfollowingでない場合は、絞り込みをせずそのまま返す
    return posts unless mode == "following"

    if authenticated && current_user.present?
      # ログイン中の場合のみ、フォロー中ユーザーの投稿に絞る
      # current_user.following_ids で、現在のユーザーがフォローしているユーザーID一覧を取得する
      posts.where(user_id: current_user.following_ids)
    else
      # 未ログインの場合はフォロー情報がないため、空の結果を返す
      # Post.noneは、投稿が0件のActiveRecord::Relationを返す
      Post.none
    end
  end

  # キーワード、タグ、期間による検索条件を適用するメソッド
  def filter_posts(posts)
    posts
      # params[:keyword]があれば、投稿タイトルや本文などをキーワード検索する
      # keyword_searchはPostモデル側に定義しているscope想定
      .keyword_search(params[:keyword])

      # params[:tag_name]があれば、タグ名で投稿を絞り込む
      # tag_searchもPostモデル側に定義しているscope想定
      .tag_search(params[:tag_name])

      # params[:period]があれば、今日・今週・今月などの期間で絞り込む
      # period_searchもPostモデル側に定義しているscope想定
      .period_search(params[:period])

      # タグ検索などで同じ投稿が重複して出る可能性があるため、
      # distinctで重複を取り除く
      .distinct
  end

  # 投稿の並び替えを行うメソッド
  def sort_posts(posts)
    case sort
    when "old"
      # 古い投稿順に並び替える
      posts.order(created_at: :asc)
    when "likes"
      # いいね数が多い順に並び替える
      posts.order(likes_count: :desc, created_at: :desc)
    when "comments"
      # コメント数が多い順に並び替える
      posts.order(comments_count: :desc, created_at: :desc)
    else
      # デフォルトは新しい投稿順だが、キーワード検索がある場合は
      # タイトルにキーワードが含まれる投稿を優先して表示する
      if params[:keyword].present?
        # ここでは「キーワードがタイトルに含まれる投稿を先に表示する」ための
        # 簡易的なスコア付けを行います。
        #
        # 仕組み:
        #  - SQLのCASE式で、タイトルにキーワードが含まれるときは0、含まれないときは1を返す
        #  - この値で昇順ソートすると、タイトルにキーワードが含まれる投稿が先に並ぶ
        #  - さらに同じスコア内では作成日時の降順で新しい順に並べる
        #
        # 注意点:
        #  - 大文字小文字を区別しない検索のために ILIKE を使っています（PostgreSQL用）
        #  - SQLを直接組み立てるため、パラメータは必ずサニタイズして渡しています

        # 検索ワードを部分一致用に整形（例: 'Ruby' -> '%Ruby%'）
        keyword = "%#{params[:keyword]}%"

        # SQLの断片を安全に作る: プレースホルダ(?)にkeywordを埋める形でサニタイズする
        # sanitize_sql_array は ActiveRecord の機能で、SQLインジェクション対策になります
        title_score_sql = ActiveRecord::Base.send(:sanitize_sql_array, [
          "(CASE WHEN posts.title ILIKE ? THEN 0 ELSE 1 END) ASC",
          keyword
        ])

        # Arel.sql で生SQLを渡して複合的な並び替えを実行する
        # ここでは "CASE式によるスコア, 作成日時 DESC" の順にソートしています
        posts.order(Arel.sql("#{title_score_sql}, posts.created_at DESC"))
      else
        posts.order(created_at: :desc)
      end
    end
  end

  # 並び替え条件をparamsから取得する
  # 例: newest, old, likes, comments など
  def sort
    params[:sort]
  end

  # 表示モードをparamsから取得する
  # 指定がなければ "all" を使う
  # all: 全体表示
  # following: フォロー中ユーザーの投稿のみ表示
  def mode
    params[:mode] || "all"
  end
end