require "test_helper"

class Admin::CommentsControllerTest < ActionDispatch::IntegrationTest
  test "should redirect index when not logged in" do
    get admin_comments_url
    assert_redirected_to admin_login_url
  end
end
