class Post < ApplicationRecord
  include Notifiable

  # 投稿は必ずユーザーに紐づく
  belongs_to :user

  # =========================
  # 関連（タグ・コメント・いいね・通知）
  # =========================

  # タグは中間テーブルを通じた多対多で管理する
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags

  # コメント・いいねは投稿に紐づく基本機能
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy

  # 通知はポリモーフィック関連で管理（いいね・コメントなど共通化）
  has_many :notifications, as: :notifiable, dependent: :destroy

  # 投稿一覧をリアルタイム更新（Turbo Streams）
  broadcasts_refreshes

  # フォーム入力用（時間とタグは分割して受け取る）
  attr_accessor :study_time_hour, :study_time_minute, :tag_names

  # =========================
  # バリデーション
  # =========================

  validates :title, presence: true
  validates :body, presence: true

  # 学習時間は分単位で保存し、0以上の整数に制限する
  validates :study_time,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # 分は0〜59の範囲で入力させる
  validate :study_time_minute_range

  # 入力された「時間・分」を1つの分数値に変換する
  before_validation :combine_study_time

  # =========================
  # ステータス管理（公開・下書き）
  # =========================

  # 投稿の公開状態を管理（下書き機能）
  enum :status, { published: 0, draft: 1 }

  # 公開投稿のみ取得するスコープ
  scope :published_posts, -> { where(status: :published) }

  # =========================
  # 検索・フィルタ機能
  # =========================

  # キーワード検索（タイトル・本文）
  scope :keyword_search, ->(keyword) {
    return all if keyword.blank?

    where("title LIKE ? OR body LIKE ?", "%#{keyword}%", "%#{keyword}%")
  }

  # タグ検索
  scope :tag_search, ->(tag_name) {
    return all if tag_name.blank?

    joins(:tags).where(tags: { name: tag_name }).distinct
  }

  # 期間検索（今日・直近◯日など）
  scope :period_search, ->(period) {
    return all if period.blank?

    case period
    when "today"
      where(created_at: Time.zone.today.all_day)
    when "3days"
      where(created_at: 3.days.ago.beginning_of_day..Time.current)
    when "7days"
      where(created_at: 7.days.ago.beginning_of_day..Time.current)
    when "30days"
      where(created_at: 30.days.ago.beginning_of_day..Time.current)
    when "this_month"
      where(created_at: Time.zone.now.beginning_of_month..Time.current)
    else
      all
    end
  }

  # =========================
  # コールバック（通知）
  # =========================

  # 投稿作成時、公開状態ならフォロワーに通知する
  after_create_commit :notify_followers_if_published

  # =========================
  # 表示用メソッド
  # =========================

  # 学習時間（分）→ 時間に変換
  def study_time_hour
    return 0 if study_time.blank?
    study_time / 60
  end

  # 学習時間（分）→ 残り分に変換
  def study_time_minute
    return 0 if study_time.blank?
    study_time % 60
  end

  # タグ一覧をカンマ区切り文字列で取得（フォーム表示用）
  def tag_names
    tags.pluck(:name).join(", ")
  end

  # 指定ユーザーがいいねしているか判定
  def liked_by?(user)
    return false if user.blank?

    likes.exists?(user_id: user.id)
  end

  # タグを文字列から分解して保存（新規作成含む）
  def save_tags(tag_names)
    return if tag_names.nil?

    tag_list = tag_names.split(",").map(&:strip).reject(&:blank?).uniq

    self.tags = tag_list.map do |tag_name|
      Tag.find_or_create_by!(name: tag_name)
    end
  end

  private

  # =========================
  # 学習時間処理
  # =========================

  # 入力された時間・分を合算して分単位に変換する
  def combine_study_time
    return if @study_time_hour.blank? && @study_time_minute.blank?

    hour = @study_time_hour.to_i
    minute = @study_time_minute.to_i

    self.study_time = (hour * 60) + minute
  end

  # 分の入力値が0〜59の範囲内かチェック
  def study_time_minute_range
    return if @study_time_minute.blank?

    minute = @study_time_minute.to_i
    return if minute.between?(0, 59)

    errors.add(:study_time_minute, "は0〜59の間で入力してください")
  end

  # =========================
  # 通知処理
  # =========================

  # 公開投稿の場合、フォロワー全員に投稿通知を送る
  def notify_followers_if_published
    return unless published?

    user.followers.find_each do |follower|
      create_notification!(
        recipient: follower,
        actor: user,
        action: :posted,
        notifiable: self
      )
    end
  end
end