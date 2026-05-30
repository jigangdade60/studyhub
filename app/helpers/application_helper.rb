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
    image_cache_key = if user&.profile_image&.attached?
                        user.profile_image.blob.cache_key
                      else
                        "no_image"
                      end

    cache_key = ["user-avatar", user&.cache_key_with_version || "guest", image_cache_key, size, extra_class]

    Rails.cache.fetch(cache_key) do
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

  def unread_notifications_count
    return 0 unless Current.user.present?

    Current.user.received_notifications.unread.count
  end
end
