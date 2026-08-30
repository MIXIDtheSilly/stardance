json.users @users do |user|
  json.partial! "api/v1/users/user", user: user, viewer: @current_api_user
end

json.partial! "api/v1/pagination", pagy: @pagy
