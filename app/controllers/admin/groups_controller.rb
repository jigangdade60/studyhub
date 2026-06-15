class Admin::GroupsController < ApplicationController
  # ================================
  # 管理者用グループ管理コントローラー
  # ================================
  # このコントローラーは、管理画面からグループ一覧を確認したり、
  # 不適切なグループを削除したりするための処理を担当する。
  #
  # Public側のグループ機能とは異なり、
  # 一般ユーザーではなく管理者が操作する前提のコントローラー。

  # 管理者としてログインしているユーザーだけが
  # このコントローラーの機能を利用できるようにする。
  #
  # index や destroy が実行される前に必ず呼ばれ、
  # 管理者でなければ管理者ログイン画面へリダイレクトする。
  before_action :require_admin_authentication

  # destroyアクションの前に、削除対象のグループを取得する。
  #
  # only: %i[destroy] とすることで、
  # グループ削除時だけ set_group を実行する。
  before_action :set_group, only: %i[destroy]

  def index
    # 管理者用のグループ一覧を取得する。
    #
    # Group.includes(:owner, :members)
    # → グループ作成者(owner)と参加メンバー(members)を
    #   あらかじめまとめて取得する。
    #
    # これにより、ビューで owner や members を表示するときに
    # グループごとに追加SQLが何度も発行される N+1問題 を防ぐ。
    @groups = Group.includes(:owner, :members)
                   .order(created_at: :desc) # 新しく作成されたグループから順に表示する
                   .page(params[:page])      # URLパラメータのページ番号に応じてページネーションする
                   .per(10)                  # 1ページあたり10件ずつ表示する

    # グループ作成者を配列として取り出す。
    #
    # @groups.map(&:owner)
    # → 各グループの owner を取り出す。
    #
    # compact
    # → nil が含まれていた場合に取り除く。
    owners = @groups.map(&:owner).compact

    # 各グループに参加しているメンバーを配列として取り出す。
    #
    # flat_map を使うことで、
    # グループごとの members 配列を1つの配列にまとめる。
    members = @groups.flat_map(&:members)

    # owner と members をまとめて、プロフィール画像を事前読み込みする。
    #
    # profile_image_attachment: :blob
    # → Active Storage のプロフィール画像情報をまとめて取得する。
    #
    # これにより、ビューでプロフィール画像を表示するときに
    # ユーザーごとに画像取得SQLが発行される N+1問題 を防ぐ。
    #
    # (owners + members).any?
    # → 対象ユーザーが1人以上いる場合だけ Preloader を実行する。
    ActiveRecord::Associations::Preloader.new(
      records: owners + members,
      associations: { profile_image_attachment: :blob }
    ).call if (owners + members).any?
  end

  def destroy
    # 管理者権限でグループを削除する。
    #
    # 一般ユーザー側では、通常グループ作成者本人しか
    # 削除できないように制御するが、
    # 管理画面では不適切なグループを管理者が削除できる。
    @group.destroy

    # 削除後は管理者用グループ一覧画面へリダイレクトする。
    #
    # notice には i18n の翻訳キーを使い、
    # 「グループを削除しました」のようなメッセージを表示する。
    redirect_to admin_groups_path, notice: t("flash.notice.group_deleted")
  end

  private

  def set_group
    # URLパラメータの id から削除対象のグループを取得する。
    #
    # 例：
    # DELETE /admin/groups/5
    # のようなリクエストの場合、params[:id] は "5" になる。
    #
    # Group.find(params[:id])
    # → id が一致するグループを1件取得する。
    #
    # 存在しない id の場合は ActiveRecord::RecordNotFound が発生する。
    @group = Group.find(params[:id])
  end

  def require_admin_authentication
    # 現在、管理者としてログインしているか確認する。
    #
    # current_admin は、ログイン中の管理者を返すメソッド。
    # 管理者ログイン済みであれば current_admin が存在する。
    return if current_admin.present?

    # 管理者としてログインしていない場合は、
    # 管理者ログイン画面へリダイレクトする。
    #
    # alert には i18n の翻訳キーを使い、
    # 「管理者としてログインしてください」のようなメッセージを表示する。
    redirect_to admin_login_path, alert: t("flash.alert.admin_login_required")
  end
end
