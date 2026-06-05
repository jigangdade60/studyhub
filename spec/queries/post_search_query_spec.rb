require 'rails_helper'

RSpec.describe PostSearchQuery, type: :model do
  describe '#call' do
    it 'prioritizes posts with keyword in title' do
      user = User.create!(email: 'user@example.com', password: 'password')

      post_in_title = Post.create!(
        title: 'Ruby on Rails Tips',
        body: 'Useful tips',
        status: :published,
        user: user
      )

      post_in_body = Post.create!(
        title: 'Random Thoughts',
        body: 'I love Ruby programming',
        status: :published,
        user: user
      )

      results = PostSearchQuery.new(params: { keyword: 'Ruby' }, current_user: nil, authenticated: false).call

      expect(results.first).to eq(post_in_title)
      expect(results).to include(post_in_body)
    end
  end
end
