require "test_helper"
require "base64"

class Api::V1::ShopItemsControllerTest < ActionDispatch::IntegrationTest
  API_FLAG = :"public_api_2026-08-28"

  setup do
    @user = User.create!(slack_id: "U_API_SHOP", display_name: "shop_reader", email: "shop_reader@example.test", verification_status: "verified")
    @user.regenerate_api_key
    Flipper.enable(API_FLAG, @user)

    @item = create_shop_item(name: "Orbital Mug", ticket_cost: 100)
  end

  teardown do
    Flipper.disable(API_FLAG, @user)
  end

  test "index requires an api key" do
    get api_v1_shop_items_path

    assert_response :unauthorized
    assert_equal "Missing Authorization header", response.parsed_body["error"]
  end

  test "index rejects an unknown api key" do
    get api_v1_shop_items_path, headers: { "Authorization" => "Bearer sd_sk_nope" }

    assert_response :unauthorized
    assert_equal "Invalid API key", response.parsed_body["error"]
  end

  test "index is forbidden when the api flag is off for the user" do
    Flipper.disable(API_FLAG, @user)

    get api_v1_shop_items_path, headers: auth_headers

    assert_response :forbidden
  end

  test "index returns a page of items with regional pricing and availability" do
    get api_v1_shop_items_path, headers: auth_headers

    assert_response :success
    body = response.parsed_body
    assert_equal({ "current_page" => 1, "total_pages" => 1, "total_count" => 1, "next_page" => nil }, body["pagination"])

    item = body["shop_items"].sole
    assert_equal @item.id, item["id"]
    assert_equal "Orbital Mug", item["name"]
    assert_equal "ShopItem::ThirdPartyPhysical", item["type"]
    assert item["image_url"].present?
    assert item["image_thumb_url"].present?
    assert_equal [], item["old_prices"]
    assert_equal [], item["attached_shop_item_ids"]

    assert_equal %w[enabled_au enabled_ca enabled_eu enabled_in enabled_uk enabled_us enabled_xx],
                 item["enabled"].keys.sort
    assert_equal %w[au base_cost ca eu in uk us xx], item["ticket_cost"].keys.sort
    assert_equal 100, item["ticket_cost"]["base_cost"]
    assert_equal 100, item["ticket_cost"]["us"]
  end

  test "ticket_cost reflects a sale discount" do
    @item.update!(sale_percentage: 25)

    get api_v1_shop_item_path(@item), headers: auth_headers

    assert_response :success
    assert_equal 100, response.parsed_body["ticket_cost"]["base_cost"]
    assert_equal 75, response.parsed_body["ticket_cost"]["us"]
  end

  test "old_prices lists previous ticket costs" do
    @item.update!(ticket_cost: 150)

    get api_v1_shop_item_path(@item), headers: auth_headers

    assert_response :success
    assert_equal [ 100 ], response.parsed_body["old_prices"]
    assert_equal 150, response.parsed_body["ticket_cost"]["base_cost"]
  end

  test "attached_shop_item_ids lists the item's accessories" do
    accessory = create_accessory(name: "Mug Lid", parent: @item)

    get api_v1_shop_item_path(@item), headers: auth_headers

    assert_response :success
    assert_equal [ accessory.id ], response.parsed_body["attached_shop_item_ids"]
  end

  test "index omits items the shop does not list" do
    hidden = {
      draft: create_shop_item(name: "Draft Item", ticket_cost: 1, draft: true),
      unlisted: create_shop_item(name: "Unlisted Item", ticket_cost: 1, unlisted: true),
      disabled: create_shop_item(name: "Disabled Item", ticket_cost: 1, enabled: false),
      expired: create_shop_item(name: "Expired Item", ticket_cost: 1, enabled_until: 1.day.ago),
      prize_only: create_shop_item(name: "Prize Item", ticket_cost: 1, mission_prize_only: true),
      accessory: create_accessory(name: "Mug Lid", parent: @item),
      tutorial: create_shop_item(name: "Free Stickers", ticket_cost: 0, type: "ShopItem::FreeStickers")
    }

    get api_v1_shop_items_path, headers: auth_headers

    assert_response :success
    ids = response.parsed_body["shop_items"].map { |i| i["id"] }
    assert_equal [ @item.id ], ids
    hidden.each { |reason, item| assert_not_includes ids, item.id, "expected #{reason} item to be hidden" }
  end

  test "show returns a single item" do
    get api_v1_shop_item_path(@item), headers: auth_headers

    assert_response :success
    assert_equal @item.id, response.parsed_body["id"]
  end

  test "show 404s for an item the shop does not list" do
    draft = create_shop_item(name: "Draft Item", ticket_cost: 1, draft: true)

    get api_v1_shop_item_path(draft), headers: auth_headers

    assert_response :not_found
    assert_equal "Resource not found", response.parsed_body["error"]
  end

  test "index rejects a limit above the maximum page size" do
    get api_v1_shop_items_path, params: { limit: 5_000 }, headers: auth_headers

    assert_response :bad_request
    assert_equal "Limit cannot exceed 100", response.parsed_body["error"]
  end

  test "show 404s for an unknown item" do
    get api_v1_shop_item_path(id: 0), headers: auth_headers

    assert_response :not_found
  end

  private
    def auth_headers
      { "Authorization" => "Bearer #{@user.api_key}" }
    end

    def create_shop_item(name:, ticket_cost:, type: "ShopItem::ThirdPartyPhysical", **attrs)
      item = ShopItem.new(
        name: name,
        description: "#{name} description",
        ticket_cost: ticket_cost,
        type: type,
        enabled: true,
        **attrs
      )
      item.image.attach(
        io: StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=")),
        filename: "item.png",
        content_type: "image/png"
      )
      item.save!
      item
    end

    # An accessory that can't be bought on its own has to be attached to a
    # parent item before that flag is valid, so it's flipped after attaching.
    def create_accessory(name:, parent:)
      accessory = create_shop_item(name: name, ticket_cost: 10, type: "ShopItem::Accessory", buyable_by_self: true)
      ShopItemAttachment.create!(parent_item: parent, accessory_item: accessory)
      accessory.update!(buyable_by_self: false)
      accessory
    end
end
