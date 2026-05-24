class BackfillPostCounters < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    say_with_time "Backfilling posts.likes_count and posts.comments_count" do
      Post.find_each(batch_size: 100) do |post|
        Post.reset_counters(post.id, :likes)
        Post.reset_counters(post.id, :comments)
      end
    end
  end

  def down
    # no-op
  end
end
