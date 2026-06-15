class GroupMembership < ApplicationRecord
  # =========================
  # 関連付け
  # =========================

  # GroupMembership は「どのグループに所属しているか」を表すため、
  # group テーブルと紐づける
  #
  # 例：
  # group_memberships テーブルに group_id があり、
  # その group_id を使って groups テーブルのデータを参照できる
  belongs_to :group

  # GroupMembership は「どのユーザーが所属しているか」も表すため、
  # user テーブルと紐づける
  #
  # 例：
  # group_memberships テーブルに user_id があり、
  # その user_id を使って users テーブルのデータを参照できる
  belongs_to :user

  # =========================
  # バリデーション
  # =========================

  # 同じユーザーが、同じグループに重複して参加できないようにする
  #
  # uniqueness は「一意性」を確認するバリデーション
  # scope: :group_id を指定することで、
  # 「同じ group_id の中では user_id が重複しない」
  # という制約になる
  #
  # つまり、
  # user_id: 1, group_id: 1
  # user_id: 1, group_id: 1
  # のような同じ組み合わせは登録できない
  #
  # 一方で、
  # user_id: 1, group_id: 1
  # user_id: 1, group_id: 2
  # のように、同じユーザーが別のグループに参加することはできる
  #
  # この制約がないと、
  # 同じユーザーが同じグループに何度も参加できてしまい、
  # メンバー数の表示や所属判定がおかしくなる可能性がある
  validates :user_id, uniqueness: { scope: :group_id }
end
