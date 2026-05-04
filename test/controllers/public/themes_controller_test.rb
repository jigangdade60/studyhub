require "test_helper"

class Public::ThemesControllerTest < ActionDispatch::IntegrationTest
  test "should get update" do
    get public_themes_update_url
    assert_response :success
  end
end
