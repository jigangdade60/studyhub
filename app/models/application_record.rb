# すべてのModelクラスが継承する基底クラス
#
# 例：
# User < ApplicationRecord
# Post < ApplicationRecord
# Comment < ApplicationRecord
#
# のように、各ModelはApplicationRecordを継承している。
class ApplicationRecord < ActiveRecord::Base
  # primary_abstract_class は、
  # このクラスが「直接DBのテーブルと対応するModelではない」
  # ということをRailsに伝えるための設定。
  #
  # 通常、RailsのModelは
  # Userモデル → usersテーブル
  # Postモデル → postsテーブル
  # のように、Model名に対応するDBテーブルを持つ。
  #
  # しかしApplicationRecordは、
  # アプリ内の全Modelに共通する親クラスであり、
  # application_recordsテーブルのようなテーブルは存在しない。
  #
  # そのため、abstract classとして扱う必要がある。
  primary_abstract_class
end
