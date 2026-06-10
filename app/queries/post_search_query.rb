# 投稿一覧画面で使う「検索・絞り込み・並び替え」をまとめたクラス
#
# Controllerに検索条件や並び替え処理をすべて書くと、
# Controllerが長くなり、何をしているか分かりにくくなる。
#
# そのため、投稿検索専用のクラスとして切り出している。
# このように、検索条件を組み立てる専用クラスを Query Object と呼ぶ。
class PostSearchQuery
  # params:
  #   検索フォームやURLパラメータから送られてくる値
  #   例: keyword, tag_name, period, sort, mode など
  #
  # current_user:
  #   ログイン中のユーザー
  #   自分の下書きを表示するか、フォロー中投稿を表示するかの判定に使う
  #
  # authenticated:
  #   ログインしているかどうかを表す真偽値
  #   true ならログイン中、false なら未ログイン
  def initialize(params:, current_user: nil, authenticated: false)
    @params = params
    @current_user = current_user
    @authenticated = authenticated
  end

  # 外部から呼び出すメインメソッド
  #
  # Controller側では、
  # PostSearchQuery.new(...).call
  # のように呼び出す。
  #
  # 処理の流れ:
  # 1. ログイン状態に応じて、元になる投稿一覧を取得する
  # 2. 「フォロー中のみ」モードなら、フォロー中ユーザーの投稿に絞る
  # 3. キーワード・タグ・期間で検索条件を適用する
  # 4. 最後に、指定された条件で並び替える
  def call
    posts = base_posts
    posts = filter_following(posts)
    posts = filter_posts(posts)
    sort_posts(posts)
  end

  private

  # このクラスの中だけで使う値を読み取れるようにしている
  #
  # attr_readerを使うことで、
  # @params ではなく params と書けるようになる。
  #
  # private配下に置いているため、
  # クラスの外から直接 params などを呼ぶことは想定していない。
  attr_reader :params, :current_user, :authenticated

  # 投稿一覧の元になるデータを取得するメソッド
  #
  # ログイン中か未ログインかで、表示できる投稿が変わる。
  #
  # ログイン中:
  #   公開投稿 + 自分の下書き投稿を表示する
  #
  # 未ログイン:
  #   公開投稿のみ表示する
  def base_posts
    if authenticated && current_user.present?
      # ログイン中の場合
      #
      # 公開投稿に加えて、自分が作成した投稿も取得する。
      # これにより、自分の下書き投稿も一覧に表示できる。
      #
      # ただし、他人の下書きは表示してはいけないため、
      # 条件は「公開投稿 OR 自分の投稿」としている。
      #
      # includesは、関連データを先にまとめて取得するためのもの。
      # 投稿一覧画面では、投稿ごとにユーザー名、プロフィール画像、
      # タグ、いいね、コメントなどを表示するため、
      # 何も対策しないとN+1問題が起きやすい。
      #
      # N+1問題とは、
      # 投稿一覧を1回取得したあとに、
      # 投稿1件ごとに関連データ取得SQLが何回も発行される問題。
      #
      # includesを使うことで、関連データを事前に読み込み、
      # SQLの発行回数を減らしている。
      #
      # user: { profile_image_attachment: :blob } は、
      # ActiveStorageで管理しているプロフィール画像を事前に読み込む指定。
      Post.includes(:tags, :likes, :comments, user: { profile_image_attachment: :blob })
          .where(
            "posts.status = ? OR posts.user_id = ?",
            Post.statuses[:published],
            current_user.id
          )
    else
      # 未ログインの場合
      #
      # 未ログインユーザーには、公開投稿のみ表示する。
      # 下書き投稿は本人以外に見せてはいけないため、ここでは除外する。
      #
      # こちらも投稿一覧で関連データを使うため、
      # includesでタグ、いいね、コメント、ユーザー、プロフィール画像を
      # 事前に読み込んでいる。
      Post.includes(:tags, :likes, :comments, user: { profile_image_attachment: :blob })
          .where(status: :published)
    end
  end

  # フォロー中ユーザーの投稿だけに絞り込むメソッド
  #
  # 投稿一覧には、
  # 全体表示とフォロー中のみ表示の2種類がある想定。
  #
  # params[:mode] が "following" の場合だけ、
  # フォロー中ユーザーの投稿に絞り込む。
  def filter_following(posts)
    # modeがfollowingでない場合は、何も絞り込まずにそのまま返す。
    return posts unless mode == "following"

    if authenticated && current_user.present?
      # ログイン中の場合のみ、フォロー中ユーザーの投稿に絞れる。
      #
      # current_user.following_ids は、
      # 現在ログインしているユーザーがフォローしているユーザーIDの配列。
      #
      # 例:
      # current_user.following_ids
      # => [2, 5, 8]
      #
      # posts.where(user_id: [2, 5, 8])
      # とすることで、フォロー中ユーザーの投稿だけを取得できる。
      posts.where(user_id: current_user.following_ids)
    else
      # 未ログインの場合
      #
      # 未ログインユーザーには「フォロー中」という概念がない。
      # そのため、mode=followingでアクセスされた場合は空の結果を返す。
      #
      # Post.none は、投稿が0件のActiveRecord::Relationを返す。
      # nilではなくRelationを返すことで、
      # その後にwhereやorderなどをつなげてもエラーになりにくい。
      Post.none
    end
  end

  # キーワード、タグ、期間による絞り込みを行うメソッド
  #
  # ここでは実際の検索処理をPostモデルのscopeに任せている。
  #
  # このクラスの役割:
  #   どの検索条件をどの順番で適用するかを管理する
  #
  # Postモデルのscopeの役割:
  #   keyword_search、tag_search、period_searchなど、
  #   具体的な検索条件を定義する
  def filter_posts(posts)
    posts
      # キーワード検索
      #
      # params[:keyword] に値がある場合、
      # 投稿タイトルや本文を対象に検索する想定。
      #
      # keyword_search は Postモデル側に定義したscope。
      .keyword_search(params[:keyword])

      # タグ検索
      #
      # params[:tag_name] に値がある場合、
      # 指定されたタグが付いた投稿に絞り込む。
      #
      # tag_search も Postモデル側に定義したscope。
      .tag_search(params[:tag_name])

      # 期間検索
      #
      # params[:period] に値がある場合、
      # 今日、今週、今月などの期間で絞り込む想定。
      #
      # period_search も Postモデル側に定義したscope。
      .period_search(params[:period])

      # distinct
      #
      # タグ検索などでJOINを使う場合、
      # 同じ投稿が重複して取得される可能性がある。
      #
      # distinctをつけることで、同じ投稿が複数回表示されるのを防ぐ。
      .distinct
  end

  # 投稿一覧の並び替えを行うメソッド
  #
  # params[:sort] の値によって並び替え条件を変えている。
  #
  # 例:
  # sort=old      → 古い順
  # sort=likes    → いいね数が多い順
  # sort=comments → コメント数が多い順
  # 指定なし      → 新しい順
  def sort_posts(posts)
    case sort
    when "old"
      # 古い投稿順に並び替える。
      #
      # created_at: :asc は、
      # 作成日時が古いものから順番に並べる指定。
      posts.order(created_at: :asc)

    when "likes"
      # いいね数が多い順に並び替える。
      #
      # likes_count は counter_cache 用のカラム。
      #
      # 毎回 likes テーブルを数えるのではなく、
      # postsテーブルに保存している likes_count を使うことで、
      # 並び替えを高速にしている。
      #
      # いいね数が同じ場合は、新しい投稿を先に表示する。
      posts.order(likes_count: :desc, created_at: :desc)

    when "comments"
      # コメント数が多い順に並び替える。
      #
      # comments_count も counter_cache 用のカラム。
      #
      # コメント数順で並び替えるときに、
      # 毎回コメント数を集計しなくてよくなる。
      #
      # コメント数が同じ場合は、新しい投稿を先に表示する。
      posts.order(comments_count: :desc, created_at: :desc)

    else
      # デフォルトの並び替え。
      #
      # 基本は新しい投稿順に表示する。
      #
      # ただし、キーワード検索をしている場合は、
      # 本文だけにキーワードがある投稿よりも、
      # タイトルにキーワードが含まれている投稿を優先して表示したい。
      #
      # 理由:
      #   タイトルに検索キーワードが含まれている投稿の方が、
      #   ユーザーの探している内容に近い可能性が高いため。
      if params[:keyword].present?
        # キーワードを部分一致検索用の形に変換する。
        #
        # 例:
        # params[:keyword] が "Ruby" の場合
        # keyword は "%Ruby%" になる。
        #
        # SQLのLIKE検索では、
        # % は「前後にどんな文字があってもよい」という意味。
        keyword = "%#{params[:keyword]}%"

        # タイトル一致を優先するためのSQLを作る。
        #
        # CASE式の意味:
        #   posts.title にキーワードが含まれていれば 0
        #   含まれていなければ 1
        #
        # その結果を昇順で並び替えるため、
        # 0 の投稿、つまりタイトルにキーワードが含まれる投稿が先に来る。
        #
        # ILIKE は大文字小文字を区別しない検索。
        # 例:
        # "Ruby" と "ruby" を同じように扱える。
        #
        # 注意:
        #   ILIKE は PostgreSQL で使える書き方。
        #   MySQLを使う場合は LIKE にするなど、DBに合わせた調整が必要。
        #
        # sanitize_sql_array を使う理由:
        #   ユーザーが入力した検索ワードをそのままSQLに埋め込むと、
        #   SQLインジェクションの危険がある。
        #
        #   プレースホルダ ? を使って安全に値を埋め込むために、
        #   sanitize_sql_array を使っている。
        title_score_sql = ActiveRecord::Base.send(:sanitize_sql_array, [
          "(CASE WHEN posts.title ILIKE ? THEN 0 ELSE 1 END) ASC",
          keyword
        ])

        # orderに作成したSQLを渡して並び替える。
        #
        # 並び順:
        # 1. タイトルにキーワードが含まれる投稿を優先
        # 2. 同じ優先度の中では新しい投稿順
        #
        # Arel.sql を使う理由:
        #   Railsでは安全性のため、orderに生のSQL文字列を渡すと
        #   警告やエラーになる場合がある。
        #
        #   ここでは、sanitize済みのSQLであることを明示するために
        #   Arel.sql を使っている。
        posts.order(Arel.sql("#{title_score_sql}, posts.created_at DESC"))
      else
        # キーワード検索がない場合は、通常通り新しい投稿順に並び替える。
        posts.order(created_at: :desc)
      end
    end
  end

  # 並び替え条件をparamsから取得するメソッド
  #
  # params[:sort] には、
  # "old", "likes", "comments" などが入る想定。
  #
  # このメソッドを作っておくことで、
  # sort_posts内で params[:sort] と直接書かずに sort と書ける。
  def sort
    params[:sort]
  end

  # 表示モードをparamsから取得するメソッド
  #
  # params[:mode] に値がない場合は "all" を使う。
  #
  # all:
  #   全体の投稿一覧を表示する
  #
  # following:
  #   フォロー中ユーザーの投稿だけを表示する
  def mode
    params[:mode] || "all"
  end
end