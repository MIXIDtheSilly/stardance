require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  API_FLAG = :"public_api_2026-08-28"

  setup do
    @user = create_discoverable_user(slack_id: "U_API_USERS", display_name: "api_reader")
    @user.regenerate_api_key
    Flipper.enable(API_FLAG, @user)

    @other = create_discoverable_user(slack_id: "U_API_OTHER", display_name: "nova_pilot")
    @project = Project.create!(title: "Nebula Drift", description: "A space sim")
    @project.memberships.create!(user: @other, role: :owner)
  end

  teardown do
    Flipper.disable(API_FLAG, @user)
  end

  test "index requires an api key" do
    get api_v1_users_path

    assert_response :unauthorized
    assert_equal "Missing Authorization header", response.parsed_body["error"]
  end

  test "index is forbidden when the api flag is off for the user" do
    Flipper.disable(API_FLAG, @user)

    get api_v1_users_path, headers: auth_headers

    assert_response :forbidden
  end

  test "index returns a page of users with their projects" do
    get api_v1_users_path, headers: auth_headers

    assert_response :success
    body = response.parsed_body
    assert_includes body["users"].map { |u| u["id"] }, @user.id

    other = body["users"].find { |u| u["id"] == @other.id }
    assert_equal "nova_pilot", other["display_name"]
    assert_equal "U_API_OTHER", other["slack_id"]
    assert other["avatar"].present?
    assert_equal [ @project.id ], other["project_ids"]
  end

  test "index omits banned and non-discoverable users" do
    banned = create_discoverable_user(slack_id: "U_API_BANNED", display_name: "banned_one", banned: true)
    no_identity = User.create!(slack_id: "U_API_NOID", display_name: "no_identity", email: "noid@example.test")

    get api_v1_users_path, headers: auth_headers

    assert_response :success
    ids = response.parsed_body["users"].map { |u| u["id"] }
    assert_not_includes ids, banned.id
    assert_not_includes ids, no_identity.id
  end

  test "index searches by display name and slack id" do
    get api_v1_users_path, params: { query: "nova" }, headers: auth_headers
    assert_response :success
    assert_equal [ @other.id ], response.parsed_body["users"].map { |u| u["id"] }

    get api_v1_users_path, params: { query: "U_API_OTHER" }, headers: auth_headers
    assert_response :success
    assert_equal [ @other.id ], response.parsed_body["users"].map { |u| u["id"] }
  end

  test "stardust is hidden unless the user opted into the leaderboard" do
    @other.update!(approx_balance: 500)

    get api_v1_user_path(@other), headers: auth_headers
    assert_response :success
    assert_nil response.parsed_body["stardust"], "opted-out balance must not leak"

    @other.preference.update!(leaderboard_optin: true)

    get api_v1_user_path(@other), headers: auth_headers
    assert_response :success
    assert_equal 500, response.parsed_body["stardust"]
  end

  test "stardust is always visible for the authenticated user" do
    @user.update!(approx_balance: 250)

    get api_v1_user_path("me"), headers: auth_headers

    assert_response :success
    assert_equal 250, response.parsed_body["stardust"]
  end

  test "show never exposes private user fields" do
    get api_v1_user_path(@other), headers: auth_headers

    assert_response :success
    leaked = response.parsed_body.keys & %w[
      email guest_email hcb_email api_key session_token ip_address user_agent
      first_name last_name internal_notes banned_reason granted_roles
      geocoded_lat geocoded_lon geocoded_country verification_status
    ]
    assert_empty leaked, "private fields leaked: #{leaked.join(', ')}"
  end

  test "show returns activity stats and achievements" do
    @other.update_columns(votes_count: 3)
    @other.achievements.create!(achievement_slug: Achievement.all_slugs.first, earned_at: Time.current)

    get api_v1_user_path(@other), headers: auth_headers

    assert_response :success
    body = response.parsed_body
    assert_equal 3, body["vote_count"]
    assert_equal 0, body["like_count"]
    assert_equal 0, body["devlog_seconds_total"]
    assert_equal 0, body["devlog_seconds_today"]

    achievement = body["achievements"].sole
    assert_equal Achievement.all_slugs.first.to_s, achievement["slug"]
    assert achievement["name"].present?
  end

  test "show resolves me to the authenticated user" do
    get api_v1_user_path("me"), headers: auth_headers

    assert_response :success
    assert_equal @user.id, response.parsed_body["id"]
  end

  test "show 404s for an unknown or non-discoverable user" do
    banned = create_discoverable_user(slack_id: "U_API_BANNED2", display_name: "banned_two", banned: true)

    get api_v1_user_path(banned), headers: auth_headers
    assert_response :not_found

    get api_v1_user_path(id: 0), headers: auth_headers
    assert_response :not_found
    assert_equal "Resource not found", response.parsed_body["error"]
  end

  test "user projects index lists only that user's projects" do
    mine = Project.create!(title: "My Own Thing", description: "Mine")
    mine.memberships.create!(user: @user, role: :owner)

    get api_v1_user_projects_path(@other), headers: auth_headers

    assert_response :success
    assert_equal [ @project.id ], response.parsed_body["projects"].map { |p| p["id"] }

    get api_v1_user_projects_path("me"), headers: auth_headers

    assert_response :success
    assert_equal [ mine.id ], response.parsed_body["projects"].map { |p| p["id"] }
  end

  test "user projects index 404s for an unknown user" do
    get api_v1_user_projects_path(user_id: 0), headers: auth_headers

    assert_response :not_found
  end

  private
    def auth_headers
      { "Authorization" => "Bearer #{@user.api_key}" }
    end

    def create_discoverable_user(slack_id:, display_name:, **attrs)
      user = User.create!(slack_id: slack_id, display_name: display_name, email: "#{display_name}@example.test", verification_status: "verified", **attrs)
      user.identities.create!(provider: "hack_club", uid: "hca_#{display_name}", access_token: "token-#{display_name}")
      user
    end
end
