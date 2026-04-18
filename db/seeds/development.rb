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
# 日本語テンプレ
# =========================
titles = [
  "Railsでいいね機能を実装しました",
  "SQLのJOINを復習",
  "ポートフォリオのUI改善",
  "今日の学習記録",
  "N+1問題を解消しました",
  "通知機能の設計を見直し中",
  "バリデーションを整理しました"
]

post_bodies = [
  "今日はRailsでいいね機能を実装しました。思ったよりシンプルで理解が深まりました。",
  "SQLのJOINを復習しました。まだ曖昧な部分があるので引き続き学習します。",
  "ポートフォリオのUIを改善中です。少しずつ見やすくなってきました。",
  "N+1問題をincludesで解消しました。かなりスッキリしました。",
  "通知機能を実装しました。設計を考えるのが楽しかったです。",
  "今日はあまり進まなかったけど、少しだけ前進。",
  "エラーに時間を使ったけど原因が分かってスッキリ。",
  "バリデーション周りを整理しました。コードが読みやすくなりました。"
]

comment_bodies = [
  "すごく参考になりました！",
  "自分も同じところで詰まっていました",
  "この書き方わかりやすいですね",
  "あとで試してみます！",
  "ナイス実装です👏",
  "勉強になります！",
  "自分も改善してみます",
  "いい視点ですね"
]

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
      title: titles.sample,
      body: post_bodies.sample,
      study_time: rand(10..180),
      created_at: rand(1..7).days.ago
    )

    # タグ付け（1〜3個）
    post.tags << tags.sample(rand(1..3)) if post.respond_to?(:tags)

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
    next if post.user == user # 自分の投稿にはいいねしない

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
    user = users.sample
    next if post.user == user # 自分の投稿にはコメントしない

    Comment.create!(
      user: user,
      post: post,
      body: comment_bodies.sample,
      created_at: rand(1..5).days.ago
    )
  end
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