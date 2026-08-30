json.extract! shop_item, :id, :name, :description, :long_description, :type,
                         :limited, :stock, :max_qty, :one_per_person_ever,
                         :buyable_by_self, :show_in_carousel, :accessory_tag,
                         :sale_percentage, :agh_contents

json.old_prices shop_item.old_prices
json.attached_shop_item_ids shop_item.shop_item_attachments.map(&:accessory_item_id)
json.image_url shop_item.image.attached? ? rails_blob_url(shop_item.image) : nil
json.image_thumb_url shop_item.image.attached? ? rails_representation_url(shop_item.image.variant(:carousel_sm)) : nil

json.enabled do
  Shop::Regionalizable::REGION_CODES.each do |code|
    json.set! "enabled_#{code.downcase}", shop_item.enabled_in_region?(code)
  end
end

json.ticket_cost do
  json.base_cost shop_item.ticket_cost
  Shop::Regionalizable::REGION_CODES.each do |code|
    json.set! code.downcase, shop_item.price_for_region(code)
  end
end
