unless Rails.env.development?
  puts "development環境以外ではseedを実行しません"
  exit
end

puts "Seeding started..."

Post.destroy_all
User.destroy_all

user = User.create!(
  name: "test",
  email_address: "test@example.com",
  password: "password",
  password_confirmation: "password"
)

Post.create!([
  {
    user: user,
    title: "Railsログイン機能の実装",
    body: "Rails標準認証を使ってログイン機能を実装。SessionモデルとCurrentAttributesの理解が深まった。",
    study_time: 120,
    created_at: 3.days.ago
  },
  {
    user: user,
    title: "投稿CRUD機能の完成",
    body: "投稿の作成・一覧・詳細・編集・削除まで一通り実装。バリデーションエラーの表示にも対応。",
    study_time: 150,
    created_at: 2.days.ago
  },
  {
    user: user,
    title: "BootstrapでUI改善",
    body: "フォームやカードレイアウトを整えて、見た目を改善。余白と配色を意識した。",
    study_time: 90,
    created_at: 1.day.ago
  }
])

Admin.find_or_create_by!(email_address: "admin@example.com") do |admin|
  admin.password = "password"
  admin.password_confirmation = "password"
end

puts "Seeding completed!"