class Group < ApplicationRecord
  # =========================
  # 所有者（グループ作成者）
  # =========================

  # このグループを作成したユーザーを表す関連付け
  #
  # 通常の belongs_to :user ではなく :owner という名前にしている理由は、
  # グループには「作成者」と「参加メンバー」の2種類のユーザー関係があるため。
  #
  # class_name: "User" を指定することで、
  # owner という名前の関連付けでも、実際には User モデルと紐づくことをRailsに伝えている。
  #
  # 例：
  # group.owner
  # と書くと、このグループを作成したUserを取得できる。
  belongs_to :owner, class_name: "User"

  # =========================
  # メンバー管理
  # =========================

  # グループとユーザーの参加関係を管理する中間テーブル
  #
  # 1つのグループには複数の参加情報があり、
  # 1人のユーザーも複数のグループに参加できるため、
  # group_memberships を使って多対多の関係を表現している。
  #
  # dependent: :destroy を付けることで、
  # グループが削除されたときに、そのグループへの参加情報も一緒に削除される。
  #
  # これにより、存在しないグループに対する参加データがDBに残ることを防げる。
  has_many :group_memberships, dependent: :destroy

  # グループに参加しているユーザー一覧を取得する関連付け
  #
  # group_memberships を経由して、実際の User を members として取得できる。
  #
  # through: :group_memberships は、
  # 「group_memberships を通して取得する」という意味。
  #
  # source: :user は、
  # group_memberships の中で user という関連名を参照することを示している。
  #
  # 例：
  # group.members
  # と書くと、このグループに参加しているユーザー一覧を取得できる。
  has_many :members, through: :group_memberships, source: :user

  # グループへの参加申請を管理する関連付け
  #
  # 承認制のグループ参加を実現するため、
  # いきなりメンバーに追加するのではなく、
  # まず group_join_requests に申請データを作成する。
  #
  # グループが削除された場合は、
  # そのグループに対する参加申請も不要になるため、一緒に削除する。
  has_many :group_join_requests, dependent: :destroy

  # グループ内で投稿されたメッセージを管理する関連付け
  #
  # 1つのグループには複数のメッセージが投稿されるため has_many にしている。
  #
  # グループが削除された場合、
  # そのグループ内のメッセージも意味を持たなくなるため、一緒に削除する。
  has_many :group_messages, dependent: :destroy

  # =========================
  # バリデーション
  # =========================

  # グループ名のバリデーション
  #
  # presence: true により、グループ名が空の状態で保存されることを防ぐ。
  #
  # length: { maximum: 50 } により、
  # 長すぎるグループ名を防ぎ、画面表示やDB保存時の安全性を保つ。
  validates :name, presence: true, length: { maximum: 50 }

  # グループ説明文のバリデーション
  #
  # 説明文は、ユーザーがグループの目的や内容を理解するために必要なので必須にしている。
  #
  # 最大500文字に制限することで、
  # 極端に長い文章が登録されることを防いでいる。
  validates :description, presence: true, length: { maximum: 500 }

  # グループルールのバリデーション
  #
  # rule は必須ではないため presence は付けていない。
  # ただし、入力された場合に長くなりすぎないように500文字以内に制限している。
  #
  # 例：
  # 「誹謗中傷は禁止」「毎週1回進捗共有する」などを想定している。
  validates :rule, length: { maximum: 500 }

  # 学習テーマのバリデーション
  #
  # StudyHubでは学習目的のグループを作る想定なので、
  # 何を学ぶグループなのかを明確にするため study_theme を必須にしている。
  #
  # 例：
  # Ruby、Rails、基本情報技術者試験、JavaScript など。
  validates :study_theme, presence: true, length: { maximum: 100 }

  # 最大参加人数のバリデーション
  #
  # presence: true により、最大人数が未入力の状態を防ぐ。
  #
  # numericality により、数値として正しいかをチェックしている。
  #
  # only_integer: true は、小数ではなく整数のみ許可する指定。
  #
  # greater_than: 1 により、最低2人以上のグループにしている。
  # 1人だけだと「グループ」としての意味が弱いため。
  #
  # less_than_or_equal_to: 100 により、最大100人までに制限している。
  # 人数を制限することで、管理しやすさや画面表示の負荷を考慮している。
  validates :max_members,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than: 1,
              less_than_or_equal_to: 100
            }

  # =========================
  # 検索機能
  # =========================

  # グループ名または学習テーマで検索するためのscope
  #
  # scopeを使うことで、
  # Controllerに検索条件を直接書かず、Model側に検索ロジックをまとめている。
  #
  # これにより、Controllerは「検索結果を取得する」という役割に集中でき、
  # 検索条件の詳細はModelに任せることができる。
  #
  # 例：
  # Group.search_by_keyword("Rails")
  #
  # と書くと、name または study_theme に "Rails" を含むグループを取得できる。
  scope :search_by_keyword, ->(keyword) {
    # keyword が空の場合は、検索条件をかけずに全件返す。
    #
    # これにより、検索フォームに何も入力されていない場合でも、
    # グループ一覧を通常通り表示できる。
    return all if keyword.blank?

    # LIKEを使って部分一致検索を行う。
    #
    # name LIKE :q
    # → グループ名にキーワードが含まれるかを検索
    #
    # study_theme LIKE :q
    # → 学習テーマにキーワードが含まれるかを検索
    #
    # OR を使うことで、
    # グループ名または学習テーマのどちらかに一致すれば検索結果に含める。
    #
    # q: "%#{keyword}%"
    # の % は、前後に文字があっても一致させるための指定。
    #
    # 例：
    # keyword が "Rails" の場合、
    # "Rails勉強会" や "Ruby on Rails" も検索に引っかかる。
    where("name LIKE :q OR study_theme LIKE :q", q: "%#{keyword}%")
  }

  # =========================
  # 権限・状態判定メソッド
  # =========================

  # 指定されたユーザーが、このグループの作成者かどうかを判定するメソッド
  #
  # グループ編集・削除など、
  # 作成者だけに許可したい処理で使う。
  #
  # 例：
  # group.owned_by?(current_user)
  #
  # owner == user により、
  # グループの作成者と、渡されたユーザーが同じかどうかを比較している。
  def owned_by?(user)
    owner == user
  end

  # 指定されたユーザーが、このグループに参加済みかどうかを判定するメソッド
  #
  # 参加済みのユーザーには「参加申請ボタン」を表示しない、
  # グループ内メッセージ画面へのアクセスを許可する、
  # といった場面で使える。
  #
  # user.blank? の場合は false を返す。
  # これにより、未ログインユーザーやnilが渡された場合でもエラーを防げる。
  def joined_by?(user)
    return false if user.blank?

    # members.exists?(user.id) により、
    # このグループのメンバーの中に、指定ユーザーが存在するかをDBで確認している。
    #
    # exists? は対象データが存在するかだけを確認するため、
    # 全件取得するより効率が良い。
    members.exists?(user.id)
  end

  # 指定されたユーザーが、このグループに参加申請中かどうかを判定するメソッド
  #
  # すでに申請中の場合に、
  # 「申請中」と表示したり、重複申請を防ぐために使う。
  #
  # user.blank? の場合は false を返し、
  # nilによるエラーを防いでいる。
  def pending_request_by?(user)
    return false if user.blank?

    # group_join_requests.pending により、
    # status が pending の参加申請だけに絞り込んでいる。
    #
    # exists?(user: user) により、
    # その中に指定ユーザーの申請が存在するかを確認している。
    #
    # pending は GroupJoinRequest モデルの enum で定義されている想定。
    group_join_requests.pending.exists?(user: user)
  end

  # グループが満員かどうかを判定するメソッド
  #
  # 参加申請を承認する前や、
  # 参加ボタンを表示する前に使う。
  #
  # members.count で現在の参加人数を取得し、
  # max_members 以上であれば満員と判断する。
  def full?
    members.count >= max_members
  end
end
