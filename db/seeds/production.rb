puts "🌱 Production seeding..."

# =========================
# 管理者ユーザー
# =========================
Admin.find_or_create_by!(email_address: "admin@example.com") do |admin|
  admin.password = "password"
  admin.password_confirmation = "password"
end

# =========================
# デモユーザー
# =========================
demo_user = User.find_or_create_by!(email_address: "demo@studyhub.com") do |user|
  user.name = "StudyHub公式"
  user.password = "password"
  user.password_confirmation = "password"
  user.demo = true
end

unless demo_user.profile_image.attached?
  demo_user.profile_image.attach(
    io: File.open(Rails.root.join("db/seed_images/demo_user.png")),
    filename: "demo_user.png",
    content_type: "image/png"
  )
end

# =========================
# タグ
# =========================
tag_names = ["英語", "数学", "プログラミング", "資格", "読書"]

tags = tag_names.map do |name|
  Tag.find_or_create_by!(name: name)
end if defined?(Tag)

# =========================
# デモ投稿
# =========================
if Post.where(demo: true).empty?

  post1 = Post.create!(
    user: demo_user,
    title: "StudyHubへようこそ",
    body: "📚 学習記録を投稿できるSNSです！",
    study_time: 30,
    demo: true
  )

  post2 = Post.create!(
    user: demo_user,
    title: "投稿してみましょう",
    body: "✏️ 英語30分など気軽に記録できます！",
    study_time: 30,
    demo: true
  )

  post3 = Post.create!(
    user: demo_user,
    title: "タグで仲間を見つける",
    body: "🔍 #英語 #勉強記録 などでつながれます！",
    study_time: 20,
    demo: true
  )

  # タグ紐付け
  if defined?(Tag) && post1.respond_to?(:tags)
    [post1, post2, post3].each do |post|
      post.tags = tags.sample(rand(1..2))
    end
  end

end

puts "✅ Production seed completed!"
puts "Users: #{User.count}"
puts "Posts: #{Post.count}"
puts "Tags: #{Tag.count if defined?(Tag)}"
