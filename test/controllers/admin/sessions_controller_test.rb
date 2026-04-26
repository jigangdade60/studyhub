require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get admin_login_url
    assert_response :success
  end
end
