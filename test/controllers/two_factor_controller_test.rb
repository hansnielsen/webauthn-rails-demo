require 'test_helper'

class TwoFactorControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get two_factor_index_url
    assert_response :success
  end

  test "should get new" do
    get two_factor_new_url
    assert_response :success
  end

  test "should get create" do
    get two_factor_create_url
    assert_response :success
  end

  test "should get destroy" do
    get two_factor_destroy_url
    assert_response :success
  end

  test "should get sign" do
    get two_factor_sign_url
    assert_response :success
  end

  test "should get validate" do
    get two_factor_validate_url
    assert_response :success
  end

end
