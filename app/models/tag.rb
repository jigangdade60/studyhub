class Tag < ApplicationRecord
  # =========================
  # 関連（投稿との関係）
  # =========================

  # タグと投稿の関係を管理する中間テーブル
  #
  # Tag と Post は多対多の関係になる
  # 例：
  # - 1つのタグは複数の投稿に付けられる
  # - 1つの投稿には複数のタグを付けられる
  #
  # そのため、Tag と Post を直接つなぐのではなく、
  # post_tags テーブルを間に挟んで管理している
  has_many :post_tags, dependent: :destroy

  # post_tags を経由して、このタグが付いている投稿一覧を取得できる
  #
  # 例：
  # tag.posts
  # と書くことで、そのタグが付いた投稿を取得できる
  #
  # through: :post_tags によって、
  # Tag → PostTag → Post という形で関連をたどっている
  has_many :posts, through: :post_tags

  # =========================
  # バリデーション
  # =========================

  # タグ名は必須
  #
  # タグ名が空のままだと、
  # 何のタグなのか分からないデータが作成されてしまうため
  validates :name, presence: true

  # タグ名は重複不可
  #
  # 同じ名前のタグが複数存在すると、
  # 「Ruby」というタグが複数できてしまい、
  # 検索や一覧表示の際に扱いづらくなる
  #
  # そのため、同じ名前のタグは1つだけ作成できるようにしている
  validates :name, uniqueness: true
end
