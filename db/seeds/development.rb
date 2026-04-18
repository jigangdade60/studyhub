# ⚠️ 開発環境専用
require 'faker'

puts "🌱 Faker seeding start..."

Faker::Config.locale = :ja

# =========================
# リセット
# =========================
Notification.destroy_all if defined?(Notification)
Like.destroy_all if defined?(Like)
Comment.destroy_all if defined?(Comment)
Relationship.destroy_all if defined?(Relationship)
PostTag.destroy_all if defined?(PostTag)
Post.destroy_all
User.destroy_all
Tag.destroy_all if defined?(Tag)

# =========================
# タグ作成
# =========================
tag_names = ["英語", "数学", "プログラミング", "資格", "読書", "TOEIC", "Rails"]

tags = tag_names.map do |name|
  Tag.create!(name: name)
end

# =========================
# ユーザー作成
# =========================
users = 10.times.map do
  User.create!(
    name: Faker::Name.name,
    email_address: Faker::Internet.unique.email,
    password: "password",
    password_confirmation: "password"
  )
end

# =========================
# 投稿作成
# =========================
posts = []

users.each do |user|
  rand(3..8).times do
    post = Post.create!(
      user: user,
      title: Faker::Educator.course_name,
      body: Faker::Lorem.sentence(word_count: 25),
      study_time: rand(10..180),
      created_at: rand(1..7).days.ago
    )

    # タグ付け（1〜3個）
    if post.respond_to?(:tags)
      post.tags << tags.sample(rand(1..3))
    end

    posts << post
  end
end

# =========================
# フォロー関係
# =========================
users.each do |user|
  others = users - [user]

  others.sample(rand(2..5)).each do |followed|
    if user.respond_to?(:follow)
      user.follow(followed)
    else
      Relationship.find_or_create_by!(
        follower: user,
        followed: followed
      )
    end
  end
end

# =========================
# いいね
# =========================
posts.each do |post|
  users.sample(rand(1..5)).each do |user|
    Like.find_or_create_by!(
      user: user,
      post: post
    )
  end
end

# =========================
# コメント
# =========================
posts.each do |post|
  rand(2..6).times do
    Comment.create!(
      user: users.sample,
      post: post,
      content: Faker::Lorem.sentence(word_count: 12),
      created_at: rand(1..5).days.ago
    )
  end
end

# =========================
# 通知（いいね）
# =========================
Like.all.each do |like|
  Notification.find_or_create_by!(
    recipient: like.post.user,
    actor: like.user,
    action: "like",
    notifiable: like
  )
end

# =========================
# 通知（フォロー）
# =========================
Relationship.all.each do |rel|
  Notification.find_or_create_by!(
    recipient: rel.followed,
    actor: rel.follower,
    action: "follow",
    notifiable: rel
  )
end

# =========================
# 通知（コメント）
# =========================
Comment.all.each do |comment|
  next if comment.post.user == comment.user

  Notification.find_or_create_by!(
    recipient: comment.post.user,
    actor: comment.user,
    action: "comment",
    notifiable: comment
  )
end

# =========================
# 結果表示
# =========================
puts "✅ Faker seeding completed!"
puts "Users: #{User.count}"
puts "Posts: #{Post.count}"
puts "Tags: #{Tag.count if defined?(Tag)}"
puts "Comments: #{Comment.count if defined?(Comment)}"
puts "Likes: #{Like.count if defined?(Like)}"
puts "Relationships: #{Relationship.count if defined?(Relationship)}"
puts "Notifications: #{Notification.count if defined?(Notification)}"