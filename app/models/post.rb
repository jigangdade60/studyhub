class Post < ApplicationRecord
  # =========================
  # 通知共通処理
  # =========================

  # Notifiableモジュールを読み込むことで、
  # 通知作成処理 create_notification! をこのモデル内で使えるようにしている。
  #
  # いいね・コメント・投稿・DMなど、
  # 複数のモデルで通知処理が必要になるため、
  # 共通処理をモジュールに切り出して再利用している。
  include Notifiable

  # =========================
  # ユーザーとの関連
  # =========================

  # 投稿は必ず1人のユーザーに紐づく。
  #
  # postsテーブルには user_id を持たせており、
  # 「この投稿を誰が作成したか」を管理している。
  #
  # 例：
  # post.user と書くと、その投稿を作成したユーザーを取得できる。
  belongs_to :user

  # =========================
  # 関連（タグ・コメント・いいね・通知）
  # =========================

  # 投稿とタグの関連を管理する中間テーブル。
  #
  # 1つの投稿には複数のタグを付けられ、
  # 1つのタグも複数の投稿に使われるため、
  # 投稿とタグは「多対多」の関係になる。
  #
  # 多対多の関係を直接作るのではなく、
  # post_tags という中間テーブルを通して管理している。
  #
  # dependent: :destroy により、
  # 投稿が削除されたとき、その投稿に紐づく post_tags も削除される。
  # これにより、不要な中間テーブルのデータが残ることを防いでいる。
  has_many :post_tags, dependent: :destroy

  # post_tags を通じて、投稿に紐づくタグを取得できるようにしている。
  #
  # 例：
  # post.tags と書くと、その投稿に付いているタグ一覧を取得できる。
  #
  # through: :post_tags を使うことで、
  # post_tags を経由して tags にアクセスできる。
  has_many :tags, through: :post_tags

  # 投稿に対するコメントを管理する。
  #
  # 1つの投稿には複数のコメントが付くため、
  # Post has_many comments の関係になる。
  #
  # 投稿が削除されたら、その投稿に付いているコメントも不要になるため、
  # dependent: :destroy で一緒に削除する。
  has_many :comments, dependent: :destroy

  # 投稿に対するいいねを管理する。
  #
  # 1つの投稿には複数のいいねが付くため、
  # Post has_many likes の関係になる。
  #
  # 投稿が削除されたら、その投稿へのいいねも不要になるため、
  # dependent: :destroy を指定している。
  has_many :likes, dependent: :destroy

  # 通知との関連。
  #
  # 通知は、いいね・コメント・投稿・DMなど、
  # さまざまなモデルを通知対象にできるように、
  # ポリモーフィック関連で管理している。
  #
  # as: :notifiable とすることで、
  # Notificationモデル側の notifiable に対して、
  # Postモデルも通知対象として扱える。
  #
  # 例：
  # 「新しい投稿が作成された」という通知の対象を Post にできる。
  has_many :notifications, as: :notifiable, dependent: :destroy

  # 投稿一覧をリアルタイムに更新するための設定。
  #
  # RailsのTurbo Streamsを使い、
  # 投稿が作成・更新・削除されたときに、
  # 関連する画面を自動で更新できる。
  #
  # これにより、画面を手動リロードしなくても、
  # 投稿一覧の表示を最新状態に近づけられる。
  broadcasts_refreshes

  # =========================
  # フォーム入力用の仮想属性
  # =========================

  # attr_accessor は、DBに保存しない一時的な値を扱うために使う。
  #
  # study_time_hour:
  #   フォームで入力された「時間」を一時的に受け取る。
  #
  # study_time_minute:
  #   フォームで入力された「分」を一時的に受け取る。
  #
  # tag_names:
  #   フォームで入力されたタグ文字列を一時的に受け取る。
  #
  # DBには study_time_hour や study_time_minute を別々に保存せず、
  # 最終的には study_time に「合計分」として保存している。
  attr_accessor :study_time_hour, :study_time_minute, :tag_names

  # =========================
  # バリデーション
  # =========================

  # 投稿タイトルは必須。
  #
  # タイトルが空の投稿が作られないようにしている。
  validates :title, presence: true

  # 投稿本文は必須。
  #
  # 学習内容やメモが空の投稿を防ぐために設定している。
  validates :body, presence: true

  # 学習時間のバリデーション。
  #
  # study_time はDBには「分単位の整数」として保存している。
  #
  # presence: true
  #   学習時間が空で保存されることを防ぐ。
  #
  # only_integer: true
  #   小数ではなく整数のみ許可する。
  #
  # greater_than_or_equal_to: 0
  #   マイナスの学習時間はあり得ないため、0以上に制限する。
  validates :study_time,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # 分の入力値が0〜59の範囲かをチェックする独自バリデーション。
  #
  # 例えば「1時間90分」のような入力は不自然なので、
  # 分は0〜59に制限している。
  validate :study_time_minute_range

  # バリデーションの前に、フォームから受け取った
  # 「時間」と「分」を合計して study_time に変換する。
  #
  # before_validation にしている理由は、
  # study_time の presence や numericality のチェックが行われる前に、
  # study_time に値を入れておく必要があるため。
  before_validation :combine_study_time

  # =========================
  # ステータス管理（公開・下書き）
  # =========================

  # 投稿の公開状態を enum で管理している。
  #
  # published: 公開
  # draft: 下書き
  #
  # DB上では整数で保存されるが、
  # Rails上では published や draft という名前で扱える。
  #
  # 例：
  # post.published?  # 公開投稿か判定
  # post.draft?      # 下書き投稿か判定
  # post.published!  # 公開状態に変更
  enum :status, { published: 0, draft: 1 }

  # 公開投稿のみを取得するスコープ。
  #
  # 投稿一覧などで下書き投稿を表示したくない場合に使う。
  #
  # 例：
  # Post.published_posts
  #
  # where(status: :published) と書くことで、
  # 公開状態の投稿だけを取得できる。
  scope :published_posts, -> { where(status: :published) }

  # =========================
  # 検索・フィルタ機能
  # =========================

  # キーワード検索用のスコープ。
  #
  # タイトルまたは本文にキーワードが含まれる投稿を検索する。
  #
  # keyword.blank? の場合は検索条件をかけずに all を返す。
  # これにより、検索欄が空の場合でもエラーにならず、
  # 全件表示として扱える。
  #
  # LIKE を使うことで、完全一致ではなく部分一致検索にしている。
  #
  # 例：
  # Post.keyword_search("Rails")
  # → タイトルまたは本文に Rails を含む投稿を取得する。
  scope :keyword_search, ->(keyword) {
    return all if keyword.blank?

    where("posts.title LIKE ? OR posts.body LIKE ?", "%#{keyword}%", "%#{keyword}%")
  }

  # タグ検索用のスコープ。
  #
  # 指定されたタグ名が付いている投稿を取得する。
  #
  # joins(:tags) によって tags テーブルを結合し、
  # tags.name が指定された値と一致する投稿を検索している。
  #
  # 例：
  # Post.tag_search("Ruby")
  # → Rubyタグが付いた投稿を取得する。
  scope :tag_search, ->(tag_name) {
    return all if tag_name.blank?

    joins(:tags).where(tags: { name: tag_name })
  }

  # 期間検索用のスコープ。
  #
  # 今日、直近3日、直近7日、直近30日、今月など、
  # 投稿作成日を基準に絞り込みを行う。
  #
  # period.blank? の場合は all を返し、
  # 絞り込みなしとして扱う。
  scope :period_search, ->(period) {
    return all if period.blank?

    case period
    when "today"
      # 今日作成された投稿を取得する。
      #
      # Time.zone.today.all_day により、
      # 今日の0:00〜23:59:59の範囲を指定している。
      where(created_at: Time.zone.today.all_day)

    when "3days"
      # 3日前の始まりから現在までに作成された投稿を取得する。
      where(created_at: 3.days.ago.beginning_of_day..Time.current)

    when "7days"
      # 7日前の始まりから現在までに作成された投稿を取得する。
      where(created_at: 7.days.ago.beginning_of_day..Time.current)

    when "30days"
      # 30日前の始まりから現在までに作成された投稿を取得する。
      where(created_at: 30.days.ago.beginning_of_day..Time.current)

    when "this_month"
      # 今月の月初から現在までに作成された投稿を取得する。
      where(created_at: Time.zone.now.beginning_of_month..Time.current)

    else
      # 想定外の値が渡された場合は、絞り込みを行わず全件を返す。
      all
    end
  }

  # =========================
  # コールバック（通知）
  # =========================

  # 投稿作成後に、公開投稿であればフォロワーへ通知を送る。
  #
  # after_create_commit を使っている理由は、
  # 投稿がDBに正常に保存された後で通知処理を行いたいから。
  #
  # after_create だと、トランザクションが確定する前に処理が走る可能性がある。
  # after_create_commit なら、保存が確定した後に通知できるため安全。
  after_create_commit :notify_followers_if_published

  # =========================
  # 表示用メソッド
  # =========================

  # DBに保存されている study_time は「分単位」。
  #
  # 画面では「何時間」として表示したいため、
  # 60で割って時間部分を求めている。
  #
  # 例：
  # study_time が 130 の場合
  # 130 / 60 = 2
  # → 2時間
  def study_time_hour
    return 0 if study_time.blank?

    study_time / 60
  end

  # DBに保存されている study_time から、
  # 「分」の部分だけを取り出す。
  #
  # 60で割った余りを求めることで、
  # 時間に変換しきれなかった残り分を取得している。
  #
  # 例：
  # study_time が 130 の場合
  # 130 % 60 = 10
  # → 10分
  def study_time_minute
    return 0 if study_time.blank?

    study_time % 60
  end

  # 投稿に紐づくタグ名をカンマ区切りの文字列に変換する。
  #
  # フォームの入力欄に既存タグを表示するときに使う。
  #
  # 例：
  # ["Ruby", "Rails", "AWS"]
  # → "Ruby, Rails, AWS"
  #
  # pluck(:name) はタグの name カラムだけを取得するため、
  # 必要なデータだけを効率よく取り出せる。
  def tag_names
    tags.pluck(:name).join(", ")
  end

  # 指定されたユーザーが、この投稿にいいねしているかを判定する。
  #
  # user.blank? の場合は、ログインしていない状態などを想定し、
  # false を返している。
  #
  # likes.exists?(user_id: user.id) により、
  # 該当するいいねが存在するかだけをDBに確認する。
  #
  # exists? はデータ全体を読み込まず、
  # 存在確認だけを行うため効率が良い。
  #
  # 例：
  # post.liked_by?(current_user)
  def liked_by?(user)
    return false if user.blank?

    likes.exists?(user_id: user.id)
  end

  # =========================
  # タグ保存処理
  # =========================

  # フォームから受け取ったタグ文字列を分解して保存する。
  #
  # 例：
  # "Ruby, Rails, AWS"
  # ↓
  # ["Ruby", "Rails", "AWS"]
  #
  # 文字列で受け取ったタグを配列に変換し、
  # 既存タグがあれば取得、なければ新規作成する。
  def save_tags(tag_names)
    # nil の場合は処理を行わない。
    #
    # 空文字の場合とは違い、
    # nil はそもそもタグ情報が送られていない状態として扱う。
    return if tag_names.nil?

    # カンマ区切りのタグ文字列を配列に変換する。
    #
    # split(",")
    #   カンマで文字列を分割する。
    #
    # map(&:strip)
    #   前後の空白を削除する。
    #
    # reject(&:blank?)
    #   空のタグを除外する。
    #
    # uniq
    #   重複したタグ名を1つにまとめる。
    tag_list = tag_names.split(",").map(&:strip).reject(&:blank?).uniq

    # 入力されたタグ名をもとに、Tagレコードを取得または作成する。
    #
    # find_or_create_by! を使うことで、
    # すでに同じ名前のタグがあればそれを使い、
    # なければ新しく作成する。
    #
    # !付きなので、作成に失敗した場合は例外が発生する。
    # これにより、タグ保存の失敗に気づきやすくなる。
    new_tags = tag_list.map do |tag_name|
      Tag.find_or_create_by!(name: tag_name)
    end

    # 現在紐づいているタグ名を取得する。
    #
    # 差分確認のために、既存タグ名と新しいタグ名を比較する。
    existing_names = tags.pluck(:name)

    # 新しく入力されたタグ名一覧を取得する。
    new_names = new_tags.map(&:name)

    # 既存タグと新しいタグに差分がある場合のみ更新する。
    #
    # sortして比較している理由は、
    # タグの並び順が違うだけで別物と判定されないようにするため。
    #
    # 例：
    # ["Ruby", "Rails"] と ["Rails", "Ruby"] は同じ内容として扱う。
    if existing_names.sort != new_names.sort
      # 投稿に紐づくタグを、新しいタグ一覧に置き換える。
      #
      # self.tags = new_tags により、
      # post_tags 中間テーブルの関連も更新される。
      self.tags = new_tags

      # touch により updated_at を更新する。
      #
      # 断片キャッシュを使っている場合、
      # updated_at が変わることでキャッシュキーも変わり、
      # 古いタグ表示が残らないようにできる。
      touch
    end
  end

  private

  # =========================
  # 学習時間処理
  # =========================

  # フォームで入力された「時間」と「分」を合算し、
  # DB保存用の study_time に分単位で代入する。
  #
  # 例：
  # study_time_hour = 2
  # study_time_minute = 30
  # ↓
  # study_time = 150
  #
  # DBには「2時間30分」と分けて保存するのではなく、
  # 150分として保存することで、
  # 合計学習時間の集計がしやすくなる。
  def combine_study_time
    # 時間も分も入力されていない場合は何もしない。
    #
    # 既存の study_time をそのまま使うケースもあるため、
    # 無理に0を入れないようにしている。
    return if @study_time_hour.blank? && @study_time_minute.blank?

    # フォームから受け取る値は文字列になるため、
    # to_i で整数に変換する。
    hour = @study_time_hour.to_i
    minute = @study_time_minute.to_i

    # 時間を分に変換し、分と合算して study_time に代入する。
    self.study_time = (hour * 60) + minute
  end

  # 分の入力値が0〜59の範囲内かをチェックする。
  #
  # 60分以上を許可してしまうと、
  # 「1時間90分」のような不自然な入力ができてしまうため、
  # 分は0〜59に制限している。
  def study_time_minute_range
    # 分が入力されていない場合はチェックしない。
    #
    # 空欄の場合は combine_study_time や study_time のバリデーション側で扱う。
    return if @study_time_minute.blank?

    # フォームの値は文字列なので整数に変換する。
    minute = @study_time_minute.to_i

    # 0〜59の範囲内であれば正常なので何もしない。
    return if minute.between?(0, 59)

    # 範囲外の場合はエラーメッセージを追加する。
    #
    # errors.add により、バリデーションエラーとして扱われ、
    # 保存が失敗する。
    errors.add(:study_time_minute, "は0〜59の間で入力してください")
  end

  # =========================
  # 通知処理
  # =========================

  # 投稿が公開状態で作成された場合、
  # 投稿者のフォロワー全員に通知を送る。
  #
  # 下書き投稿の場合は通知を送らない。
  #
  # これにより、
  # 「公開された投稿だけをフォロワーに知らせる」
  # という仕様を実現している。
  def notify_followers_if_published
    # published? は enum によって自動生成されるメソッド。
    #
    # 公開投稿でなければ、ここで処理を終了する。
    return unless published?

    # 投稿者のフォロワーを1人ずつ取得して通知を作成する。
    #
    # find_each を使うことで、
    # フォロワー数が多い場合でも一度に全件をメモリに読み込まず、
    # 分割して処理できる。
    user.followers.find_each do |follower|
      # Notifiableモジュールで定義した create_notification! を呼び出す。
      #
      # recipient:
      #   通知を受け取るユーザー。ここではフォロワー。
      #
      # actor:
      #   通知を発生させたユーザー。ここでは投稿者。
      #
      # action:
      #   通知の種類。ここでは「投稿された」ことを表す :posted。
      #
      # notifiable:
      #   通知対象のレコード。ここでは作成された投稿自身。
      create_notification!(
        recipient: follower,
        actor: user,
        action: :posted,
        notifiable: self
      )
    end
  end
end
