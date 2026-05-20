class UserStatistics
  def initialize(user)
    @user = user
  end

  def posts_count
    posts.count
  end

  def total_study_time
    posts.sum(:study_time)
  end

  def weekly_study_time
    posts.where(created_at: Time.current.all_week).sum(:study_time)
  end

  def streak_days
    studied_dates = posts.pluck(:created_at)
                         .map(&:to_date)
                         .uniq
                         .sort
                         .reverse

    streak = 0
    current_day = Date.current

    studied_dates.each do |date|
      if date == current_day
        streak += 1
        current_day -= 1
      else
        break
      end
    end

    streak
  end

  def weekly_study_chart_data
    today = Date.current
    days = (6.days.ago.to_date..today).to_a

    days.map do |day|
      total_minutes = posts.where(created_at: day.all_day).sum(:study_time)

      {
        label: %w[日 月 火 水 木 金 土][day.wday],
        minutes: total_minutes
      }
    end
  end

  private

  attr_reader :user

  def posts
    user.posts.order(created_at: :desc)
  end
end
