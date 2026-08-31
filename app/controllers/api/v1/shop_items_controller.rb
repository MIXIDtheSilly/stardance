class Api::V1::ShopItemsController < Api::V1::PublicApiController
  def index
    @pagy, @shop_items = pagy(:offset, api_scope.order(:id), **pagination_options)
  end

  def show
    @shop_item = api_scope.find(params[:id])
  end

  private
    def api_scope
      ShopItem.browsable.preload(:versions, :shop_item_attachments, image_attachment: { blob: :variant_records })
    end
end
