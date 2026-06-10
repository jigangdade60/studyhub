# 一般ユーザー側のトップページ・アバウトページを管理するコントローラ
# app/controllers/public/homes_controller.rb
class Public::HomesController < ApplicationController
  # topページとaboutページは、ログインしていないユーザーでも閲覧できるようにする
  #
  # ApplicationController側では基本的にログイン必須になっているため、
  # 公開ページだけは allow_unauthenticated_access を使って認証チェックをスキップする
  #
  # only: %i[top about] とすることで、
  # topアクションとaboutアクションだけを対象にしている
  allow_unauthenticated_access only: %i[top about]

  # トップページを表示するアクション
  #
  # 特別なデータ取得処理がないため、メソッドの中身は空にしている
  # Railsでは、アクション内でrenderを書かなくても、
  # app/views/public/homes/top.html.erb が自動的に表示される
  def top; end

  # アバウトページを表示するアクション
  #
  # こちらも表示するだけの静的ページなので、処理は書いていない
  # Railsの規約により、
  # app/views/public/homes/about.html.erb が自動的に表示される
  def about; end
end