# グループへの参加申請を管理するモデル
#
# 例：
# ・ユーザーが非公開グループに参加申請する
# ・グループ作成者が申請を承認する
# ・承認されたらグループメンバーになる
class GroupJoinRequest < ApplicationRecord
  # =========================
  # 関連付け
  # =========================

  # 参加申請は、必ず1つのグループに紐づく
  #
  # group_join_requests テーブルに group_id があり、
  # その group_id を使って groups テーブルのレコードと関連付けている
  #
  # 例：
  # request.group と書くと、
  # その参加申請がどのグループへの申請なのか取得できる
  belongs_to :group

  # 参加申請は、必ず1人のユーザーに紐づく
  #
  # group_join_requests テーブルに user_id があり、
  # その user_id を使って users テーブルのレコードと関連付けている
  #
  # 例：
  # request.user と書くと、
  # その参加申請を出したユーザーを取得できる
  belongs_to :user

  # =========================
  # ステータス管理
  # =========================

  # 参加申請の状態を enum で管理している
  #
  # DBには整数で保存されるが、
  # Rails上では pending / approved / rejected のように
  # 意味のある名前で扱えるようになる
  #
  # pending  : 申請中
  # approved : 承認済み
  # rejected : 拒否済み
  #
  # 例：
  # request.pending?   # 申請中かどうか
  # request.approved!  # 承認済みに変更
  # request.rejected!  # 拒否済みに変更
  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2
  }

  # =========================
  # バリデーション
  # =========================

  # 同じユーザーが、同じグループに複数回申請できないようにする
  #
  # uniqueness: { scope: :group_id } によって、
  # 「user_id 単体」ではなく
  # 「user_id と group_id の組み合わせ」が重複しないようにしている
  #
  # 例：
  # ユーザーAがグループ1に申請済みの場合、
  # もう一度グループ1に申請することはできない
  #
  # ただし、ユーザーAが別のグループ2に申請することはできる
  validates :user_id, uniqueness: { scope: :group_id }

  # すでにそのグループのメンバーになっているユーザーは、
  # 参加申請できないようにする
  #
  # 例えば、すでに参加済みのユーザーが
  # 再度「参加申請」ボタンを押した場合に不正な申請を防ぐ
  validate :user_is_not_already_member

  # グループが満員の場合は、参加申請できないようにする
  #
  # on: :create を付けているため、
  # 新規作成時だけチェックする
  #
  # 申請後にステータスを pending から approved に変えるような更新時には、
  # このバリデーションは実行されない
  validate :group_is_not_full, on: :create

  private

  # =========================
  # カスタムバリデーション
  # =========================

  # 申請したユーザーが、すでにグループメンバーかどうかを確認する
  def user_is_not_already_member
    # group または user が存在しない場合は、
    # ここではチェックせず処理を終了する
    #
    # belongs_to の必須チェックなど、
    # 他のバリデーションに任せるため
    return unless group && user

    # group.members は、そのグループに参加しているユーザー一覧を表す
    #
    # exists?(user.id) を使うことで、
    # 対象ユーザーがメンバーに含まれているかをDB上で効率よく確認している
    #
    # すでに参加している場合は、参加申請を保存できないようにエラーを追加する
    if group.members.exists?(user.id)
      # :base にエラーを追加すると、
      # 特定のカラムではなく、モデル全体に対するエラーとして扱える
      #
      # 今回は user_id や group_id 単体の問題ではなく、
      # 「すでに参加済みなのに申請しようとしている」という
      # 申請全体の問題なので :base を使っている
      errors.add(:base, "すでに参加しています。")
    end
  end

  # グループが満員かどうかを確認する
  def group_is_not_full
    # group が存在しない場合は、
    # ここではチェックせず処理を終了する
    return unless group

    # group.full? は、
    # グループが定員に達しているかどうかを判定するメソッド
    #
    # 例えば、
    # members.count >= capacity
    # のような条件を Group モデル側で定義している想定
    if group.full?
      # グループが満員の場合は、
      # 参加申請を作成できないようにエラーを追加する
      errors.add(:base, "定員に達しているため申請できません。")
    end
  end
end
