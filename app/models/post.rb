class Post < ApplicationRecord
  belongs_to :user

  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy

  # 投稿一覧をリアルタイム更新
  broadcasts_refreshes

  attr_accessor :study_time_hour, :study_time_minute, :tag_names

  validates :title, presence: true
  validates :body, presence: true
  validates :study_time,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :study_time_minute_range

  before_validation :combine_study_time

  enum :status, { published: 0, draft: 1 }

  scope :published_posts, -> { where(status: :published) }

  scope :keyword_search, ->(keyword) {
    return all if keyword.blank?

    where("title LIKE ? OR body LIKE ?", "%#{keyword}%", "%#{keyword}%")
  }

  scope :tag_search, ->(tag_name) {
    return all if tag_name.blank?

    joins(:tags).where(tags: { name: tag_name }).distinct
  }

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

  def study_time_hour
    return 0 if study_time.blank?
    study_time / 60
  end

  def study_time_minute
    return 0 if study_time.blank?
    study_time % 60
  end

  def tag_names
    tags.pluck(:name).join(", ")
  end

  def liked_by?(user)
    return false if user.blank?

    likes.exists?(user_id: user.id)
  end

  def save_tags(tag_names)
    return if tag_names.nil?

    tag_list = tag_names.split(",").map(&:strip).reject(&:blank?).uniq

    self.tags = tag_list.map do |tag_name|
      Tag.find_or_create_by!(name: tag_name)
    end
  end

  private

  def combine_study_time
    return if @study_time_hour.blank? && @study_time_minute.blank?

    hour = @study_time_hour.to_i
    minute = @study_time_minute.to_i

    self.study_time = (hour * 60) + minute
  end

  def study_time_minute_range
    return if @study_time_minute.blank?

    minute = @study_time_minute.to_i
    return if minute.between?(0, 59)

    errors.add(:study_time_minute, "は0〜59の間で入力してください")
  end
end