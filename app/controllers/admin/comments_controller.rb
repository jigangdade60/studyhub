class Admin::CommentsController < ApplicationController
  # =========================
  # 管理者側 コメント管理コントローラ
  # =========================
  # 管理画面で、ユーザーが投稿したコメントを一覧表示・削除するためのコントローラ。
  # 不適切なコメントや規約違反のコメントを、管理者が確認・削除できるようにしている。

  # 管理画面でも共通の認証機能を利用する
  # Authentication には、ログイン状態の確認や current_user / current_admin などの処理が含まれる
  include Authentication

  # destroyアクションを実行する前に、削除対象のコメントを取得する
  # before_actionを使うことで、destroy内に同じ取得処理を書かずに済み、コードの重複を防げる
  before_action :set_comment, only: [ :destroy ]

  def index
    # コメント一覧画面を表示するアクション

    # Comment.includes(:user, :post)
    # コメントに紐づく投稿者(user)と投稿(post)を、あらかじめまとめて取得する
    # これにより、ビューで comment.user や comment.post を表示するときのN+1問題を防ぐ
    #
    # order(created_at: :desc)
    # 新しく投稿されたコメントから順番に表示する
    #
    # page(params[:page]).per(10)
    # kaminariによるページネーション
    # 1ページあたり10件ずつコメントを表示する
    @comments = Comment.includes(:user, :post).order(created_at: :desc)
                       .page(params[:page]).per(10)
  end

  def destroy
    # コメント削除アクション

    # set_commentで事前に取得したコメントを削除する
    # 管理者機能なので、一般ユーザーのコメント削除とは違い、
    # コメント投稿者本人でなくても削除できる
    #
    # 例えば、不適切な内容・迷惑行為・規約違反のコメントを
    # 管理者が管理画面から削除できるようにしている
    @comment.destroy

    # 削除後は管理者用コメント一覧画面へリダイレクトする
    # noticeには、i18nで定義した削除完了メッセージを表示する
    redirect_to admin_comments_path, notice: t("flash.notice.comment_deleted")
  end

  private

  # private以下のメソッドは、このコントローラ内部だけで使う補助的な処理
  # 外部から直接呼び出す必要がないためprivateにしている

  def set_comment
    # URLパラメータのidを使って、対象のコメントを取得する
    #
    # 例:
    # DELETE /admin/comments/5
    # のようなリクエストが来た場合、params[:id]には "5" が入る
    #
    # Comment.find(params[:id])
    # idが一致するコメントを1件取得する
    #
    # 存在しないidの場合はActiveRecord::RecordNotFoundが発生する
    @comment = Comment.find(params[:id])
  end
end
