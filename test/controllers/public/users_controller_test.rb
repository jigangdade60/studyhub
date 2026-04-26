require "test_helper"

class Public::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_user_url
    assert_response :success
  end

  test "should create user" do
    assert_difference("User.count", 1) do
      post sign_up_url, params: {
        user: {
          name: "テストユーザー",
          email_address: "test@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    assert_redirected_to mypage_path
  end
end
