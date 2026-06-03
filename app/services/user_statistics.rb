# ユーザーごとの学習統計を計算するためのクラス
# Controllerに集計処理を書くと複雑になるため、
# Service Objectとして切り出している
class UserStatistics
  # 初期化時に、統計を出したいユーザーを受け取る
  def initialize(user)
    @user = user
  end

  # ユーザーの投稿数を取得する
  # postsは下部のprivateメソッドで定義している
  def posts_count
    posts.count
  end

  # ユーザーの総学習時間を取得する
  # study_timeカラムの合計値をDB側で計算している
  def total_study_time
    posts.sum(:study_time)
  end

  # 今週の学習時間を取得する
  # Time.current.all_weekで、今週の開始日から終了日までを範囲指定している
  def weekly_study_time
    posts.where(created_at: Time.current.all_week).sum(:study_time)
  end

  # 連続学習日数を計算する
  def streak_days
    # postsは、このクラス下部のprivateメソッドで定義している
    # 中身は user.posts.order(created_at: :desc)
    # initializeで受け取ったuserに紐づく投稿一覧を取得している
    #
    # pluck(:created_at)で投稿の作成日時だけを取得する
    # map(&:to_date)で日時から日付だけに変換する
    # uniqで同じ日の重複を削除する
    # sort.reverseで新しい日付順に並べる
    studied_dates = posts.pluck(:created_at)
                         .map(&:to_date)
                         .uniq
                         .sort
                         .reverse

    # 連続日数を数えるための変数
    streak = 0

    # 今日の日付から確認を始める
    current_day = Date.current

    # 学習した日付を新しい順に確認する
    studied_dates.each do |date|
      # 今日、昨日、一昨日...と連続して投稿があればカウントする
      if date == current_day
        streak += 1

        # 次は1日前の日付を確認する
        current_day -= 1
      else
        # 途中で学習していない日があれば連続記録は終了
        break
      end
    end

    # 最終的な連続学習日数を返す
    streak
  end

  # 過去7日分の学習時間をグラフ表示用のデータに整形する
  def weekly_study_chart_data
    # 今日の日付を取得する
    today = Date.current

    # 6日前から今日までの7日間の日付配列を作る
    days = (6.days.ago.to_date..today).to_a

    # 各日付ごとに学習時間を集計し、グラフで使いやすい形に変換する
    days.map do |day|
      # postsは、このクラス下部のprivateメソッドで定義している
      # 中身は user.posts.order(created_at: :desc)
      # initializeで受け取ったuserに紐づく投稿一覧を取得している
      #
      # where(created_at: day.all_day)で、その日1日分の投稿だけに絞り込む
      # sum(:study_time)で、その日の学習時間を合計する
      total_minutes = posts.where(created_at: day.all_day).sum(:study_time)

      {
        # 曜日を日本語で表示するため、wdayを使って曜日配列から取得する
        # wdayは日曜が0、月曜が1...土曜が6になる
        label: %w[日 月 火 水 木 金 土][day.wday],

        # その日の合計学習時間
        minutes: total_minutes
      }
    end
  end

  private

  # 外部から直接userを呼び出さず、このクラス内だけで使う
  attr_reader :user

  # postsメソッドは、このユーザーに紐づく投稿一覧を取得するための共通メソッド
  # user.postsは、Userモデルの has_many :posts の関連付けを使っている
  # つまり「このユーザーが作成した投稿一覧」を取得している
  # order(created_at: :desc)で、新しい投稿順に並べている
  def posts
    user.posts.order(created_at: :desc)
  end
end