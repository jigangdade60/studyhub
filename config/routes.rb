Rails.application.routes.draw do
  # ==========================================
  # 管理者側のルーティング
  # ==========================================
  #
  # namespace :admin を使うことで、
  # URLは /admin/users のように admin が付き、
  # コントローラーも Admin::UsersController のように
  # admin配下のコントローラーを参照する。
  #
  # 一般ユーザー側と管理者側の機能を明確に分けるために使っている。
  namespace :admin do
    # 管理者ログイン画面を表示するルート
    # GET /admin/login
    # Admin::SessionsController#new が呼ばれる
    get "login", to: "sessions#new"

    # 管理者ログイン処理を行うルート
    # POST /admin/login
    # 入力されたメールアドレス・パスワードを確認し、
    # 認証成功時にセッションを作成する
    post "login", to: "sessions#create"

    # 管理者ログアウト処理を行うルート
    # DELETE /admin/logout
    # セッションを削除してログアウト状態にする
    delete "logout", to: "sessions#destroy"

    # ==========================================
    # 管理者側ユーザー管理
    # ==========================================
    #
    # resources :users によって、
    # ユーザー一覧や詳細画面などのRESTfulなルートをまとめて定義している。
    #
    # only: %i[index show] により、
    # index と show だけを作成している。
    #
    # %i[index show] は、
    # [:index, :show] と同じ意味。
    resources :users, only: %i[index show] do
      # member do は、
      # 「特定の1人のユーザー」に対する追加アクションを定義するために使う。
      #
      # 例：
      # /admin/users/:id/withdraw
      # /admin/users/:id/activate
      #
      # :id が付くため、
      # どのユーザーを退会・有効化するかを指定できる。
      member do
        # ユーザーを退会状態に変更するルート
        # PATCH /admin/users/:id/withdraw
        #
        # データの一部を更新する処理なので PATCH を使っている。
        patch :withdraw

        # 退会状態のユーザーを有効化するルート
        # PATCH /admin/users/:id/activate
        #
        # こちらもユーザー状態の更新なので PATCH を使っている。
        patch :activate

        # 管理者側で、特定ユーザーのフォロー一覧を表示するルート
        # GET /admin/users/:id/following
        get :following

        # 管理者側で、特定ユーザーのフォロワー一覧を表示するルート
        # GET /admin/users/:id/followers
        get :followers
      end
    end

    # ==========================================
    # 管理者側コメント管理
    # ==========================================
    #
    # 管理者はコメント一覧の確認と削除ができる。
    #
    # index: コメント一覧表示
    # destroy: 不適切なコメントなどを削除
    resources :comments, only: %i[index destroy]

    # ==========================================
    # 管理者側グループ管理
    # ==========================================
    #
    # 管理者はグループ一覧の確認と削除ができる。
    #
    # index: グループ一覧表示
    # destroy: 不適切なグループなどを削除
    resources :groups, only: %i[index destroy]
  end

  # ==========================================
  # 一般ユーザー側のルーティング
  # ==========================================
  #
  # scope module: :public を使うことで、
  # URLには /public を付けずに、
  # コントローラーだけ Public::HomesController などを参照する。
  #
  # 例：
  # URLは /login
  # コントローラーは Public::SessionsController
  #
  # ユーザーから見えるURLをシンプルにしつつ、
  # コントローラーは public 配下に整理できる。
  scope module: :public do
    # トップページ
    # GET /
    # Public::HomesController#top が呼ばれる
    root "homes#top"

    # Aboutページ
    # GET /about
    get "/about", to: "homes#about"

    # ==========================================
    # ユーザー登録
    # ==========================================

    # 新規登録画面を表示するルート
    # GET /sign_up
    #
    # as: :new_user を付けることで、
    # new_user_path というパスヘルパーが使える。
    get "/sign_up", to: "users#new", as: :new_user

    # 新規登録処理を行うルート
    # POST /sign_up
    #
    # フォームから送られたユーザー情報を使って、
    # Userレコードを作成する。
    #
    # as: :sign_up により、
    # sign_up_path が使える。
    post "/sign_up", to: "users#create", as: :sign_up

    # ==========================================
    # ログイン・ログアウト
    # ==========================================

    # ログイン画面を表示するルート
    # GET /login
    #
    # as: :new_session により、
    # new_session_path が使える。
    get "/login", to: "sessions#new", as: :new_session

    # ログイン処理を行うルート
    # POST /login
    #
    # メールアドレスとパスワードを確認し、
    # 認証成功時にセッションを作成する。
    #
    # as: :session により、
    # session_path が使える。
    post "/login", to: "sessions#create", as: :session

    # ログアウト処理を行うルート
    # DELETE /logout
    #
    # セッション情報を削除するため、
    # データ削除の意味に近い DELETE を使っている。
    #
    # as: :logout により、
    # logout_path が使える。
    delete "/logout", to: "sessions#destroy", as: :logout

    # ==========================================
    # マイページ
    # ==========================================

    # ログイン中ユーザー自身のマイページ
    # GET /mypage
    #
    # users/:id ではなく /mypage にすることで、
    # 「自分専用ページ」であることがURLから分かりやすい。
    get "/mypage", to: "users#mypage", as: :mypage

    # ==========================================
    # 一般ユーザー機能
    # ==========================================
    #
    # usersリソースでは、ユーザー一覧・詳細・編集・更新・退会を扱う。
    #
    # index   : ユーザー一覧
    # show    : ユーザー詳細
    # edit    : プロフィール編集画面
    # update  : プロフィール更新
    # destroy : 退会処理
    resources :users, only: [ :index, :show, :edit, :update, :destroy ] do
      # member do は、
      # 特定ユーザー1人に対する追加ページを作るために使う。
      member do
        # 特定ユーザーがフォローしている人の一覧
        # GET /users/:id/following
        get :following

        # 特定ユーザーをフォローしている人の一覧
        # GET /users/:id/followers
        get :followers
      end
    end

    # ==========================================
    # 投稿機能
    # ==========================================
    #
    # resources :posts により、
    # 投稿のCRUD機能をまとめて定義している。
    #
    # index   : 投稿一覧
    # show    : 投稿詳細
    # new     : 新規投稿画面
    # create  : 投稿作成
    # edit    : 投稿編集画面
    # update  : 投稿更新
    # destroy : 投稿削除
    resources :posts do
      # ==========================================
      # コメント機能
      # ==========================================
      #
      # コメントは投稿に紐づくため、
      # posts の中に comments をネストしている。
      #
      # 例：
      # POST /posts/:post_id/comments
      #
      # :post_id がURLに含まれるため、
      # 「どの投稿に対するコメントか」が分かる。
      resources :comments, only: [ :create, :destroy ]

      # ==========================================
      # いいね機能
      # ==========================================
      #
      # resource :like は単数形。
      #
      # 1人のユーザーは、1つの投稿に対して
      # いいねを1つだけ持つ設計なので、単数 resource を使っている。
      #
      # 例：
      # POST /posts/:post_id/like
      # DELETE /posts/:post_id/like
      #
      # 「この投稿に対する自分のいいね」を作成・削除するイメージ。
      resource :like, only: [ :create, :destroy ]
    end

    # ==========================================
    # いいね一覧
    # ==========================================
    #
    # ログイン中ユーザーがいいねした投稿一覧などを表示するためのルート。
    #
    # indexのみなので、
    # GET /likes
    # だけを定義している。
    resources :likes, only: [ :index ]

    # ==========================================
    # フォロー機能
    # ==========================================
    #
    # relationships は、
    # ユーザー同士のフォロー関係を表す中間テーブル。
    #
    # create  : フォローする
    # destroy : フォロー解除する
    #
    # 複数のフォロー関係を扱うため、
    # resource ではなく resources の複数形を使っている。
    resources :relationships, only: %i[create destroy]

    # ==========================================
    # グループ機能
    # ==========================================
    #
    # groupsでは、学習グループの一覧・詳細・作成を扱う。
    #
    # index  : グループ一覧
    # show   : グループ詳細
    # new    : グループ作成画面
    # create : グループ作成処理
    resources :groups, only: %i[index show new create] do
      # member do なので、
      # 特定のグループに対する追加ページを定義している。
      member do
        # 特定グループへの参加申請一覧を表示する
        # GET /groups/:id/requests
        get :requests
      end

      # ==========================================
      # グループ参加申請
      # ==========================================
      #
      # 参加申請は「どのグループに対する申請か」が必要なので、
      # groups の中にネストしている。
      #
      # POST /groups/:group_id/group_join_requests
      resources :group_join_requests, only: %i[create]

      # ==========================================
      # グループメッセージ
      # ==========================================
      #
      # グループメッセージも、
      # どのグループに投稿されたメッセージかが重要なので、
      # groups の中にネストしている。
      #
      # POST /groups/:group_id/group_messages
      resources :group_messages, only: %i[create]
    end

    # ==========================================
    # グループ参加申請の承認・拒否
    # ==========================================
    #
    # resources :group_join_requests, only: [] は、
    # 通常のCRUDルートは作らず、
    # approve / reject だけを追加するために使っている。
    #
    # 参加申請そのものに対して承認・拒否を行うため、
    # groups配下ではなく group_join_requests 単体のルートにしている。
    resources :group_join_requests, only: [] do
      member do
        # 参加申請を承認する
        # PATCH /group_join_requests/:id/approve
        #
        # status を approved に変更する処理なので PATCH を使う。
        patch :approve

        # 参加申請を拒否する
        # PATCH /group_join_requests/:id/reject
        #
        # status を rejected に変更する処理なので PATCH を使う。
        patch :reject
      end
    end

    # ==========================================
    # DMルーム機能
    # ==========================================
    #
    # dm_rooms は、2人のユーザー間のDM部屋を表す。
    #
    # show   : DMルームの表示
    # create : DMルームの作成、または既存ルームへの遷移
    resources :dm_rooms, only: %i[show create] do
      # ==========================================
      # DMメッセージ
      # ==========================================
      #
      # DMメッセージは必ずDMルームに紐づくため、
      # dm_rooms の中にネストしている。
      #
      # POST /dm_rooms/:dm_room_id/dm_messages
      #
      # URLに :dm_room_id が入るため、
      # どのDMルームに送信されたメッセージかを特定できる。
      resources :dm_messages, only: :create
    end

    # ==========================================
    # 通知機能
    # ==========================================
    #
    # notifications は、
    # いいね・コメント・フォロー・DMなどの通知を扱う。
    #
    # index : 通知一覧
    resources :notifications, only: [ :index ] do
      # member do は、
      # 特定の通知1件に対する処理を定義する。
      member do
        # 通知1件を既読にする
        # PATCH /notifications/:id/read
        #
        # read_at などの既読状態を更新するため PATCH を使う。
        patch :read
      end

      # collection do は、
      # 特定の1件ではなく、通知全体に対する処理を定義する。
      collection do
        # 通知をすべて既読にする
        # PATCH /notifications/read_all
        #
        # 1件ではなく一覧全体に対する処理なので、
        # member ではなく collection を使っている。
        patch :read_all
      end
    end

    # ==========================================
    # テーマ切り替え機能
    # ==========================================
    #
    # resource :theme は単数形。
    #
    # テーマ設定は、ログイン中ユーザーに対して1つの設定として扱うため、
    # 複数形の resources ではなく単数 resource を使っている。
    #
    # PATCH /theme
    #
    # ダークモード・ライトモードなどの表示設定を更新する。
    resource :theme, only: [ :update ]
  end
end