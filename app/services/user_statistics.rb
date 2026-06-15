# ユーザーごとの学習統計を計算するためのクラス
#
# このクラスは Service Object として作成している。
#
# Service Objectとは、
# Controllerに書くと長くなりすぎる処理や、
# 複数の処理をまとめたビジネスロジックを
# 1つの専用クラスとして切り出す設計のこと。
#
# 今回の場合、
# 「投稿数」
# 「総学習時間」
# 「今週の学習時間」
# 「連続学習日数」
# 「グラフ表示用の学習時間データ」
# など、ユーザーに紐づく統計処理をまとめている。
#
# Controller側では、
# UserStatistics.new(@user).total_study_time
# のように呼び出すだけで済むため、
# Controllerをシンプルに保つことができる。
class UserStatistics
  # 初期化時に、統計を計算したいユーザーを受け取る
  #
  # 例：
  # statistics = UserStatistics.new(@user)
  #
  # ここで受け取った user は、
  # このクラス内で @user として保持される。
  #
  # そのため、このクラスの各メソッドでは、
  # 「どのユーザーの統計を計算するのか」を
  # 毎回引数で渡さなくてもよくなる。
  def initialize(user)
    @user = user
  end

  # ユーザーの投稿数を取得するメソッド
  #
  # posts は、このクラスの下部にある private メソッドで定義している。
  #
  # posts の中身は、
  # user.posts.order(created_at: :desc)
  #
  # つまり、
  # 「このユーザーに紐づく投稿一覧」を取得している。
  #
  # count は、投稿レコードの件数を数える ActiveRecord のメソッド。
  #
  # 面接での説明：
  # 「対象ユーザーに紐づく投稿数を取得しています。
  # user.posts の関連付けを使い、countで件数を数えています。」
  def posts_count
    posts.count
  end

  # ユーザーの総学習時間を取得するメソッド
  #
  # study_time カラムには、投稿ごとの学習時間が入っている想定。
  # 例：30分、60分、90分など
  #
  # sum(:study_time) は、
  # 対象ユーザーの投稿に含まれる study_time を
  # すべて合計する処理。
  #
  # Ruby側で1件ずつ足し算するのではなく、
  # DB側で合計しているため効率がよい。
  #
  # 面接での説明：
  # 「ユーザーの投稿に保存されている学習時間を
  # DB側で合計して、総学習時間を出しています。」
  def total_study_time
    posts.sum(:study_time)
  end

  # 今週の学習時間を取得するメソッド
  #
  # Time.current.all_week は、
  # 今週の開始日時から終了日時までの範囲を表す。
  #
  # 例：
  # 月曜日 00:00:00 〜 日曜日 23:59:59
  #
  # where(created_at: Time.current.all_week) によって、
  # 今週作成された投稿だけに絞り込んでいる。
  #
  # その後、sum(:study_time) で
  # 今週分の学習時間だけを合計している。
  #
  # 面接での説明：
  # 「今週作成された投稿に絞り込み、
  # その投稿のstudy_timeを合計して今週の学習時間を計算しています。」
  def weekly_study_time
    posts.where(created_at: Time.current.all_week).sum(:study_time)
  end

  # 連続学習日数を計算するメソッド
  #
  # 目的：
  # 今日、昨日、一昨日...と連続して学習投稿があるかを確認し、
  # 何日連続で学習しているかを計算する。
  #
  # 例：
  # 今日投稿あり
  # 昨日投稿あり
  # 一昨日投稿あり
  # 3日前投稿なし
  #
  # この場合、連続学習日数は3日になる。
  def streak_days
    # posts は、このクラス下部の private メソッドで定義している。
    #
    # 中身は、
    # user.posts.order(created_at: :desc)
    #
    # つまり、
    # initializeで受け取った user に紐づく投稿一覧を取得している。
    #
    # pluck(:created_at) は、
    # 投稿データ全体ではなく、created_at カラムだけをDBから取得する。
    #
    # 例：
    # [
    #   2026-06-10 10:00:00,
    #   2026-06-10 20:00:00,
    #   2026-06-09 09:00:00
    # ]
    #
    # map(&:to_date) は、
    # 日時データから「日付だけ」を取り出す処理。
    #
    # 例：
    # 2026-06-10 10:00:00
    # ↓
    # 2026-06-10
    #
    # uniq は、同じ日付の重複を削除する。
    #
    # 同じ日に複数投稿していても、
    # 連続学習日数としては1日分として扱いたいため。
    #
    # sort は日付を古い順に並べる。
    #
    # reverse は並び順を反転させて、
    # 新しい日付順にしている。
    #
    # 結果として studied_dates には、
    # 「学習した日付」が新しい順で入る。
    studied_dates = posts.pluck(:created_at)
                         .map(&:to_date)
                         .uniq
                         .sort
                         .reverse

    # 連続学習日数を数えるための変数
    #
    # 最初はまだ何日連続か分からないため 0 にしている。
    streak = 0

    # 今日の日付を取得する
    #
    # Date.current はRailsで現在の日付を取得するメソッド。
    #
    # Time.current は日時、
    # Date.current は日付のみを扱う。
    #
    # 今回は「日単位」で比較したいため Date.current を使っている。
    current_day = Date.current

    # 学習した日付を新しい順に1つずつ確認する。
    #
    # studied_dates の例：
    # [
    #   2026-06-10,
    #   2026-06-09,
    #   2026-06-08
    # ]
    studied_dates.each do |date|
      # date が current_day と同じなら、
      # その日は学習していると判断する。
      #
      # 最初は current_day が今日なので、
      # 今日の投稿があるかを確認する。
      #
      # その後 current_day を1日前にずらして、
      # 昨日、一昨日...と順番に確認していく。
      if date == current_day
        # 連続して学習している日数を1増やす
        streak += 1

        # 次に確認する日付を1日前にする
        #
        # 例：
        # 今日が 2026-06-10 の場合
        # 次は 2026-06-09 を確認する。
        current_day -= 1
      else
        # もし date が current_day と一致しなければ、
        # 途中で学習していない日があるということ。
        #
        # 連続記録はそこで途切れるため、
        # それ以降の日付は確認せず break でループを終了する。
        #
        # 例：
        # 今日投稿あり
        # 昨日投稿なし
        # 一昨日投稿あり
        #
        # この場合、連続日数は1日で止まる。
        break
      end
    end

    # 最終的な連続学習日数を返す
    #
    # Rubyではメソッドの最後に書いた値が戻り値になるため、
    # returnを書かなくても streak が返る。
    streak
  end

  # 過去7日分の学習時間をグラフ表示用のデータに整形するメソッド
  #
  # 目的：
  # Chart.jsなどで学習時間グラフを表示するために、
  # 過去7日分の「曜日」と「学習時間」を配列形式で返す。
  #
  # 返り値の例：
  # [
  #   { label: "木", minutes: 30 },
  #   { label: "金", minutes: 60 },
  #   { label: "土", minutes: 0 },
  #   { label: "日", minutes: 120 },
  #   { label: "月", minutes: 45 },
  #   { label: "火", minutes: 90 },
  #   { label: "水", minutes: 20 }
  # ]
  #
  # View側ではこのデータを使って、
  # 曜日ごとの学習時間グラフを作成できる。
  def weekly_study_chart_data
    # 今日の日付を取得する
    #
    # Date.current を使うことで、
    # Railsのタイムゾーン設定を考慮した現在日付を取得できる。
    today = Date.current

    # 6日前から今日までの7日間の日付配列を作る
    #
    # 例：
    # 今日が 2026-06-10 の場合
    #
    # 2026-06-04 〜 2026-06-10
    #
    # という7日分の日付配列になる。
    #
    # to_a によって、日付の範囲を配列に変換している。
    days = (6.days.ago.to_date..today).to_a

    # 7日分の日付を1日ずつ処理して、
    # グラフで使いやすいハッシュ形式に変換する。
    #
    # map は、配列の各要素を変換して
    # 新しい配列を作るメソッド。
    days.map do |day|
      # day.all_day は、
      # その日の開始時刻から終了時刻までの範囲を表す。
      #
      # 例：
      # 2026-06-10 00:00:00 〜 2026-06-10 23:59:59
      #
      # where(created_at: day.all_day) によって、
      # その日に作成された投稿だけに絞り込んでいる。
      #
      # sum(:study_time) によって、
      # その日の学習時間を合計している。
      #
      # 投稿がない日は合計が0になる。
      total_minutes = posts.where(created_at: day.all_day).sum(:study_time)

      {
        # label は、グラフの横軸に表示する曜日。
        #
        # day.wday は曜日を数値で返す。
        #
        # 日曜日：0
        # 月曜日：1
        # 火曜日：2
        # 水曜日：3
        # 木曜日：4
        # 金曜日：5
        # 土曜日：6
        #
        # %w[日 月 火 水 木 金 土] は、
        # 曜日を日本語で並べた配列。
        #
        # そのため、
        # %w[日 月 火 水 木 金 土][day.wday]
        # と書くことで、数値から日本語の曜日を取得できる。
        label: %w[日 月 火 水 木 金 土][day.wday],

        # minutes は、その日の合計学習時間。
        #
        # Chart.jsなどでは、
        # この値を縦軸のデータとして使う。
        minutes: total_minutes
      }
    end
  end

  private

  # attr_reader :user によって、
  # @user を user というメソッド名で参照できるようにしている。
  #
  # 例：
  # @user.posts
  # と書く代わりに、
  # user.posts
  # と書ける。
  #
  # private の下に書いているため、
  # このクラスの外部からは user を直接呼び出せない。
  #
  # 外部から直接 user を扱わせず、
  # このクラス内の処理として閉じ込める意図がある。
  attr_reader :user

  # このユーザーに紐づく投稿一覧を取得するための共通メソッド
  #
  # user.posts は、Userモデルの has_many :posts の関連付けを使っている。
  #
  # つまり、
  # 「このユーザーが作成した投稿一覧」
  # を取得している。
  #
  # order(created_at: :desc) は、
  # 投稿日時が新しい順に並び替える処理。
  #
  # 複数のメソッドで user.posts を使うため、
  # posts という private メソッドにまとめている。
  #
  # こうすることで、
  # 各メソッドで毎回
  # user.posts.order(created_at: :desc)
  # と書かなくて済む。
  #
  # また、投稿の取得条件を変更したい場合も、
  # この posts メソッドだけを修正すればよくなる。
  #
  # 面接での説明：
  # 「ユーザーに紐づく投稿取得処理を共通化するために
  # privateメソッドとしてpostsを定義しています。
  # 各統計メソッドではこのpostsを使って集計しています。」
  def posts
    user.posts.order(created_at: :desc)
  end
end
