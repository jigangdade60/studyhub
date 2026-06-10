class Admin::UsersController < Admin::BaseController
  # ================================
  # 管理者用ユーザー管理コントローラー
  # ================================
  # このコントローラーは、管理者画面からユーザー情報を確認したり、
  # ユーザーの有効・退会状態を切り替えたりするための処理を担当する。
  #
  # Admin::BaseController を継承しているため、
  # 管理者としてログインしていないユーザーはアクセスできない。
  #
  # 一般ユーザー側の UsersController とは異なり、
  # 管理者が全ユーザーを管理するためのコントローラー。

  def index
    # 管理者画面で全ユーザーを一覧表示する。
    #
    # User.order(created_at: :desc)
    # → 作成日時が新しいユーザーから順番に取得する。
    #
    # with_attached_profile_image
    # → Active Storage のプロフィール画像を事前読み込みする。
    #   これにより、一覧画面でプロフィール画像を表示する際に
    #   ユーザーごとに追加SQLが発行される N+1問題 を防ぐ。
    #
    # page(params[:page]).per(10)
    # → kaminari によるページネーション。
    #   URLの page パラメータに応じて、1ページ10件ずつ表示する。
    @users = User.order(created_at: :desc)
                 .with_attached_profile_image
                 .page(params[:page])
                 .per(10)
  end

  def show
    # 管理者が個別ユーザーの詳細情報を確認する。
    #
    # params[:id]
    # → URLに含まれるユーザーID。
    #
    # 例：
    # GET /admin/users/5
    # の場合、params[:id] は "5" になる。
    #
    # User.find(params[:id])
    # → id が一致するユーザーを1件取得する。
    #
    # 存在しないIDの場合は ActiveRecord::RecordNotFound が発生する。
    @user = User.find(params[:id])
  end

  def update
    # 更新対象のユーザーを取得する。
    #
    # 管理者画面から送信されたURLの id をもとに、
    # 状態変更するユーザーを特定する。
    @user = User.find(params[:id])

    # 管理者がユーザー情報を更新する。
    #
    # user_params を使うことで、
    # 管理者画面から更新できる項目を制限している。
    #
    # このコードでは :is_active のみ許可しているため、
    # 名前やメールアドレスなどを不正に変更されることを防げる。
    if @user.update(user_params)
      # 更新に成功した場合は、対象ユーザーの詳細画面へリダイレクトする。
      #
      # notice には i18n の翻訳キーを使い、
      # 「ユーザー情報を更新しました」のようなメッセージを表示する。
      redirect_to admin_user_path(@user), notice: t("flash.notice.user_updated")
    else
      # 更新に失敗した場合の処理。
      #
      # 例えば、バリデーションエラーなどで保存できなかった場合に実行される。
      #
      # flash.now は、redirect_to ではなく render で同じ画面を表示する場合に使う。
      # 次のリクエストには残らず、現在の画面表示だけでメッセージを出せる。
      flash.now[:alert] = t("flash.alert.update_failed")

      # show画面を再表示する。
      #
      # redirect_to ではなく render を使うことで、
      # @user のエラー情報を保持したまま画面を表示できる。
      #
      # status: :unprocessable_entity
      # → 入力内容に問題があり、更新処理ができなかったことを表す。
      render :show, status: :unprocessable_entity
    end
  end

  def withdraw
    # 退会処理の対象ユーザーを取得する。
    #
    # 管理者が特定ユーザーを退会状態に変更するため、
    # URLの id から対象ユーザーを取得している。
    @user = User.find(params[:id])

    # ユーザーを物理削除せず、退会状態にする。
    #
    # is_active を false にすることで、
    # アカウントは残したまま「退会済み」として扱う。
    #
    # 物理削除しない理由：
    # ・投稿、コメント、いいね、通知などの関連データを残せる
    # ・過去の学習記録や投稿履歴との整合性を保てる
    # ・必要に応じて後から復元できる
    #
    # update! は保存に失敗した場合に例外を発生させるメソッド。
    # 管理者操作として、失敗を見逃さないようにしている。
    @user.update!(is_active: false)

    # 退会状態に変更した後は、対象ユーザーの詳細画面へ戻る。
    #
    # notice には i18n の翻訳キーを使い、
    # 「ユーザーを退会状態にしました」のようなメッセージを表示する。
    redirect_to admin_user_path(@user), notice: t("flash.notice.user_withdrawn")
  end

  def activate
    # 有効化する対象ユーザーを取得する。
    #
    # 退会状態のユーザーを再び利用可能にするため、
    # URLの id から対象ユーザーを取得している。
    @user = User.find(params[:id])

    # 退会状態のユーザーを再び有効化する。
    #
    # is_active を true にすることで、
    # ログイン可能な通常ユーザーとして扱えるようにする。
    #
    # 管理者が誤って退会状態にした場合や、
    # 再開希望があった場合に対応できる。
    @user.update!(is_active: true)

    # 有効化後は、対象ユーザーの詳細画面へ戻る。
    #
    # notice には i18n の翻訳キーを使い、
    # 「ユーザーを有効化しました」のようなメッセージを表示する。
    redirect_to admin_user_path(@user), notice: t("flash.notice.user_activated")
  end

  private

  def user_params
    # ================================
    # ストロングパラメータ
    # ================================
    # 管理者画面から更新を許可する項目を制限する。
    #
    # params.require(:user)
    # → user というキーが必ず含まれていることを確認する。
    #
    # permit(:is_active)
    # → 更新を許可するカラムを is_active のみに限定する。
    #
    # これにより、フォームやリクエストを改ざんされても、
    # email_address や password などの重要な項目が
    # 勝手に更新されることを防げる。
    params.require(:user).permit(:is_active)
  end
end