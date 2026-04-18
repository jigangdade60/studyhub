puts "🌱 Seeding (#{Rails.env})..."

if Rails.env.production?
  require Rails.root.join("db/seeds/production")
else
  require Rails.root.join("db/seeds/development")
end

puts "✅ Seed finished!"