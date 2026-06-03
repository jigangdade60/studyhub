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
      # likes_countはcounter_cacheで保持しているカラム
      # likesテーブルを毎回集計せずに並び替えられるため、パフォーマンスが良い
      posts.order(likes_count: :desc, created_at: :desc)
    when "comments"
      # コメント数が多い順に並び替える
      # comments_countもcounter_cacheで保持しているカラム
      posts.order(comments_count: :desc, created_at: :desc)
    else
      # デフォルトは新しい投稿順
      posts.order(created_at: :desc)
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