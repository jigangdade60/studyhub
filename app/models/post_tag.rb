# 投稿とタグの関連を管理する中間テーブル用のモデル
#
# PostTag は、
# 「どの投稿に、どのタグが付いているか」
# を管理するためのモデルです。
#
# 例：
# post_id: 1, tag_id: 3
# → 「IDが1の投稿に、IDが3のタグが付いている」
# という意味になります。
class PostTag < ApplicationRecord
  # =========================
  # アソシエーション
  # =========================

  # PostTag は1つの投稿に紐づく
  #
  # post_tags テーブルには post_id があり、
  # その post_id を使って posts テーブルの投稿と関連付ける
  #
  # これにより、
  # post_tag.post
  # のように書くと、このタグ付けがどの投稿に紐づいているか取得できる
  belongs_to :post

  # PostTag は1つのタグに紐づく
  #
  # post_tags テーブルには tag_id があり、
  # その tag_id を使って tags テーブルのタグと関連付ける
  #
  # これにより、
  # post_tag.tag
  # のように書くと、このタグ付けがどのタグを表しているか取得できる
  belongs_to :tag

  # =========================
  # バリデーション
  # =========================

  # 同じ投稿に、同じタグが重複して付かないようにする
  #
  # uniqueness: { scope: :tag_id } は、
  # 「post_id 単体で一意」ではなく、
  # 「post_id と tag_id の組み合わせで一意」
  # という意味
  #
  # 例：
  # post_id: 1, tag_id: 2 → OK
  # post_id: 1, tag_id: 3 → OK
  # post_id: 2, tag_id: 2 → OK
  # post_id: 1, tag_id: 2 → NG
  #
  # つまり、
  # 「同じ投稿に同じタグを2回付けること」は禁止し、
  # 「別の投稿に同じタグを付けること」は許可している
  validates :post_id, uniqueness: { scope: :tag_id }
end