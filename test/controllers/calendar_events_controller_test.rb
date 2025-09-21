require "test_helper"

class CalendarEventsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get calendar_events_index_url
    assert_response :success
  end

  test "should get show" do
    get calendar_events_show_url
    assert_response :success
  end

  test "should get new" do
    get calendar_events_new_url
    assert_response :success
  end

  test "should get create" do
    get calendar_events_create_url
    assert_response :success
  end

  test "should get edit" do
    get calendar_events_edit_url
    assert_response :success
  end

  test "should get update" do
    get calendar_events_update_url
    assert_response :success
  end

  test "should get destroy" do
    get calendar_events_destroy_url
    assert_response :success
  end
end
