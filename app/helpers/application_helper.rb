module ApplicationHelper
  def format_study_time(minutes)
    return "0分" if minutes.blank?

    hours = minutes / 60
    remaining_minutes = minutes % 60

    if hours.positive? && remaining_minutes.positive?
      "#{hours}時間#{remaining_minutes}分"
    elsif hours.positive?
      "#{hours}時間"
    else
      "#{remaining_minutes}分"
    end
  end
end