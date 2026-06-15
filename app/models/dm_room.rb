class DmRoom < ApplicationRecord
  # ==============================
  # 関連付け
  # ==============================

  # DMルームは2人のユーザーで構成される
  #
  # 通常 belongs_to :user と書くと、
  # Railsは user_id というカラムを探す。
  #
  # しかし、このモデルでは
  # user1_id と user2_id という2つの外部キーを使って、
  # 「DMに参加している2人のユーザー」を表している。
  #
  # そのため、class_name: "User" を指定して、
  # user1 も user2 も Userモデルに紐づくことを明示している。
  belongs_to :user1, class_name: "User"
  belongs_to :user2, class_name: "User"

  # 1つのDMルームには、複数のDMメッセージが存在する。
  #
  # 例：
  # DmRoom 1件
  #   ├ dm_message 1件目
  #   ├ dm_message 2件目
  #   └ dm_message 3件目
  #
  # dependent: :destroy を指定しているため、
  # DMルームが削除された場合、そのルームに紐づくメッセージも一緒に削除される。
  #
  # これにより、存在しないDMルームに紐づいたメッセージだけが
  # DBに残ってしまうことを防いでいる。
  has_many :dm_messages, dependent: :destroy

  # ==============================
  # バリデーション
  # ==============================

  # 同じユーザー同士のDMルームを作成できないようにする。
  #
  # 例えば、
  # user1_id: 1
  # user2_id: 1
  # のような「自分自身とのDM」は不要なので禁止している。
  validate :different_users

  # user1_id と user2_id の順番を統一するためのバリデーション。
  #
  # このアプリでは、
  # user1_id < user2_id
  # になるように保存するルールにしている。
  #
  # 例えば、ユーザーIDが 3 と 5 の2人なら、
  # 必ず
  # user1_id: 3
  # user2_id: 5
  # として保存する。
  #
  # こうすることで、
  # user1_id: 3, user2_id: 5
  # user1_id: 5, user2_id: 3
  # のように、同じ2人のDMルームが重複して作られることを防ぎやすくなる。
  validate :ordered_users

  # ==============================
  # クラスメソッド
  # ==============================

  # 2人のユーザー間のDMルームを取得する。
  # まだ存在しない場合は、新しく作成する。
  #
  # self. がついているため、インスタンスメソッドではなくクラスメソッド。
  #
  # 使い方の例：
  # DmRoom.find_or_create_between(current_user, @user)
  #
  # このメソッドを使うことで、コントローラー側で
  # 「既存ルームを探す」
  # 「なければ作る」
  # という処理を毎回書かなくて済む。
  def self.find_or_create_between(user_a, user_b)
    # 2人のユーザーIDを配列に入れて、昇順に並び替える。
    #
    # 例：
    # user_a.id が 5、user_b.id が 3 の場合
    # [5, 3].sort は [3, 5] になる。
    #
    # smaller_id には小さいID、
    # larger_id には大きいIDが入る。
    smaller_id, larger_id = [ user_a.id, user_b.id ].sort

    # user1_id に小さいID、
    # user2_id に大きいIDを入れてDMルームを探す。
    #
    # find_or_create_by! は、
    # 条件に一致するレコードがあればそれを返し、
    # なければ新しく作成する。
    #
    # ! がついているため、作成に失敗した場合は例外を発生させる。
    # これにより、失敗を見逃さずに検知できる。
    find_or_create_by!(user1_id: smaller_id, user2_id: larger_id)
  end

  # ==============================
  # インスタンスメソッド
  # ==============================

  # 指定したユーザーが、このDMルームの参加者かどうかを判定する。
  #
  # user1_id または user2_id が、
  # 渡された user.id と一致すれば参加者と判断する。
  #
  # DmMessageモデル側で、
  # 「メッセージ送信者がこのDMルームの参加者かどうか」
  # を確認するためにも使える。
  def includes_user?(user)
    user1_id == user.id || user2_id == user.id
  end

  # 現在ログインしているユーザーから見た「相手ユーザー」を取得する。
  #
  # DM画面では、
  # 「自分」ではなく「相手の名前やアイコン」を表示したいことが多い。
  #
  # そのため、current_user が user1 なら user2 を返し、
  # current_user が user2 なら user1 を返す。
  def other_user(current_user)
    user1_id == current_user.id ? user2 : user1
  end

  private

  # ==============================
  # privateメソッド
  # ==============================
  #
  # 以下のメソッドは、外部から直接呼び出すものではなく、
  # バリデーションの内部処理として使うため private にしている。

  # 自分自身とのDMルームを禁止するためのバリデーション。
  #
  # user1_id と user2_id が同じ場合、
  # 同一ユーザー同士のDMになってしまう。
  #
  # その場合は errors.add でエラーメッセージを追加し、
  # 保存できないようにしている。
  def different_users
    errors.add(:base, "同じユーザー同士ではDMできません") if user1_id == user2_id
  end

  # user1_id と user2_id の順番をチェックするバリデーション。
  #
  # このアプリでは、
  # user1_id は user2_id より小さい
  # というルールでDMルームを保存している。
  #
  # このルールを守ることで、
  # 同じ2人の組み合わせが逆順で重複保存されることを防ぐ。
  def ordered_users
    # user1_id または user2_id が空の場合は、
    # ここでは順序チェックを行わない。
    #
    # belongs_to の存在チェックなど、
    # 他のバリデーションに任せる。
    return if user1_id.blank? || user2_id.blank?

    # user1_id が user2_id より小さければ正常なので何もしない。
    return if user1_id < user2_id

    # user1_id が user2_id 以上の場合は、
    # 保存ルールに違反しているためエラーを追加する。
    errors.add(:base, "user1_idはuser2_idより小さくしてください")
  end
end
