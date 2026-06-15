class Relationship < ApplicationRecord
  # =========================
  # 自己結合（User同士のフォロー関係）
  # =========================
  #
  # Relationshipモデルは、
  # 「誰が」「誰を」フォローしているかを管理する中間テーブルです。
  #
  # 例：
  # user_id: 1 のユーザーが user_id: 2 のユーザーをフォローする場合、
  # follower_id: 1
  # followed_id: 2
  # という1件のRelationshipレコードを作成します。
  #
  # Userモデル同士の関係なので「自己結合」と呼ばれます。

  # =========================
  # 関連付け
  # =========================

  # フォローする側のユーザー
  #
  # relationshipsテーブルには follower_id というカラムがあります。
  # ただし、Railsは通常 follower というモデルを探そうとするため、
  # class_name: "User" を指定して、
  # follower は Userモデルを参照することを明示しています。
  belongs_to :follower, class_name: "User"

  # フォローされる側のユーザー
  #
  # relationshipsテーブルには followed_id というカラムがあります。
  # followed も Userモデルを参照するため、
  # class_name: "User" を指定しています。
  belongs_to :followed, class_name: "User"

  # =========================
  # バリデーション
  # =========================

  # follower_id は必須
  #
  # 「誰がフォローしたのか」が空だと、
  # フォロー関係として成り立たないため必須にしています。
  validates :follower_id, presence: true

  # followed_id は必須
  #
  # 「誰をフォローしたのか」が空だと、
  # フォロー関係として成り立たないため必須にしています。
  validates :followed_id, presence: true

  # 同じユーザーを重複してフォローできないようにする
  #
  # scope: :followed_id を指定することで、
  # 「follower_id と followed_id の組み合わせ」が
  # 重複しないようにしています。
  #
  # 例：
  # follower_id: 1, followed_id: 2
  # のレコードがすでにある場合、
  # 同じ組み合わせのレコードは作成できません。
  #
  # これにより、同じ相手を何度もフォローすることを防げます。
  validates :follower_id, uniqueness: { scope: :followed_id }

  # 自分自身をフォローできないようにする独自バリデーション
  #
  # presence や uniqueness だけでは、
  # follower_id と followed_id が同じ値かどうかまでは判定できません。
  #
  # そのため、独自メソッド cannot_follow_self を使って、
  # 自分自身へのフォローを禁止しています。
  validate :cannot_follow_self

  private

  # =========================
  # 独自バリデーション用メソッド
  # =========================

  # フォローする側とフォローされる側が同じ場合、
  # バリデーションエラーを追加する
  #
  # 例：
  # follower_id: 1
  # followed_id: 1
  #
  # このようなデータは「自分で自分をフォローする」状態になるため、
  # アプリの仕様として禁止しています。
  def cannot_follow_self
    if follower_id == followed_id
      errors.add(:followed_id, "自分自身はフォローできません")
    end
  end
end
