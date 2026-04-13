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

  def user_avatar(user, size: 40, extra_class: "")
    image =
      if user&.profile_image&.attached?
        user.profile_image
      else
        "no_image.jpg"
      end

    image_tag(
      image,
      size: "#{size}x#{size}",
      class: "avatar-icon rounded-circle #{extra_class}"
    )
  end
end