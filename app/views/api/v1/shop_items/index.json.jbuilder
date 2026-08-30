json.shop_items @shop_items do |shop_item|
  json.partial! "api/v1/shop_items/shop_item", shop_item: shop_item
end

json.partial! "api/v1/pagination", pagy: @pagy
