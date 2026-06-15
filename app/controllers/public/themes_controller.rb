class Public::ThemesController < ApplicationController
  # =========================
  # テーマ切り替え用コントローラ
  # =========================
  #
  # このコントローラでは、ログイン中ユーザーの表示テーマを
  # light / dark のどちらかに切り替える処理を行う。
  #
  # 例：
  # - 現在 light の場合 → dark に変更
  # - 現在 dark の場合 → light に変更

  # テーマ切り替えボタンは PATCH リクエストで update アクションに送信される。
  #
  # 通常 Rails では CSRF 対策として authenticity_token の検証が行われるが、
  # 非ブラウザ環境でのテストや一部のリクエスト形式では
  # CSRF 検証エラーが発生することがある。
  #
  # そのため、この update アクションに限って CSRF 検証をスキップしている。
  #
  # ※ 面接では補足として、
  # 「本番運用では安易に CSRF を無効化せず、
  #   Turbo やフォームの authenticity_token を正しく送る設計が望ましい」
  # と説明できると安全性への理解も伝わる。
  skip_before_action :verify_authenticity_token, only: :update

  def update
    # ログイン中ユーザーの現在のテーマを確認し、
    # dark であれば light に、light であれば dark に切り替える。
    #
    # current_user.dark? は、ユーザーの theme カラムが
    # "dark" かどうかを判定するメソッド。
    #
    # 三項演算子を使って、
    # 条件 ? trueの場合 : falseの場合
    # の形で切り替え後の値を決めている。
    #
    # current_user.dark? ? "light" : "dark"
    # → darkモード中なら light にする
    # → それ以外なら dark にする

    # update_column を使うことで、バリデーションを通さずに
    # theme カラムだけを直接更新している。
    #
    # ここではプロフィール情報など他の必須項目のバリデーションに
    # 影響されず、テーマ変更だけを確実に保存したいため使用している。
    #
    # ただし update_column は以下の特徴がある。
    # - バリデーションを実行しない
    # - コールバックを実行しない
    # - updated_at は自動更新されない
    #
    # そのため、使いどころを限定する必要がある。
    current_user.update_column(:theme, current_user.dark? ? "light" : "dark")

    # テーマ変更後は、元いたページに戻す。
    #
    # redirect_back は直前のページにリダイレクトするメソッド。
    # ただし、リファラ情報がない場合もあるため、
    # fallback_location で戻り先が分からない場合の遷移先を指定している。
    #
    # ここでは、戻り先が分からない場合は投稿一覧ページへ遷移する。
    redirect_back fallback_location: posts_path
  end
end
