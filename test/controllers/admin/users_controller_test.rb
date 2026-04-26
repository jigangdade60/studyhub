require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should redirect index when not logged in" do
    get admin_users_url
    assert_redirected_to admin_login_url
  end

  test "should redirect show when not logged in" do
    get admin_user_url(users(:one))
    assert_redirected_to admin_login_url
  end
end
