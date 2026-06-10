# ApplicationController は、すべてのコントローラの親クラスです。
# Rails では、各コントローラは基本的にこの ApplicationController を継承します。
#
# 例：
# Public::PostsController < ApplicationController
# Public::UsersController < ApplicationController
#
# そのため、ここに共通処理を書くことで、
# アプリ全体のコントローラで同じ処理を使えるようになります。
class ApplicationController < ActionController::Base

  # Authentication モジュールを読み込んでいます。
  #
  # Authentication には、
  # ・ログイン状態の復元
  # ・ログイン必須チェック
  # ・current_user の取得
  # ・未ログインユーザーの制御
  # など、認証に関する共通処理をまとめています。
  #
  # ApplicationController で include することで、
  # すべてのコントローラで認証処理を共通利用できます。
  #
  # これにより、各コントローラに毎回同じログイン確認処理を書かずに済み、
  # コードの重複を減らすことができます。
  include Authentication
end