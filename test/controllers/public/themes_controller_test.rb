require "test_helper"

class Public::ThemesControllerTest < ActionDispatch::IntegrationTest
  test "should get update" do
    # sign in via sessions#create using fixture credentials
    post session_url, params: { email_address: users(:one).email_address, password: "password" }

    patch theme_url
    assert_response :redirect
  end
end
