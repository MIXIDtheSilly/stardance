class Api::V1::UsersController < Api::V1::PublicApiController
  def index
    scope = api_scope.order(:id)
    scope = scope.where("users.display_name ILIKE :q OR users.slack_id ILIKE :q", q: "%#{User.sanitize_sql_like(params[:query])}%") if params[:query].present?

    @pagy, @users = pagy(:offset, scope, **pagination_options)
  end

  def show
    @user = find_api_user(params[:id], scope: api_scope)
  end

  private
    def api_scope
      User.discoverable.preload(:projects, :preference)
    end
end
