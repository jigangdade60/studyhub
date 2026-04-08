class Post < ApplicationRecord
  belongs_to :user

  attr_accessor :study_time_hour, :study_time_minute

  validates :title, presence: true
  validates :body, presence: true
  validates :study_time,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :study_time_minute_range

  before_validation :combine_study_time

  def study_time_hour
    return 0 if study_time.blank?
    study_time / 60
  end

  def study_time_minute
    return 0 if study_time.blank?
    study_time % 60
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