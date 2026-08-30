json.partial! "api/v1/users/user", user: @user, viewer: @current_api_user

json.vote_count @user.votes_count
json.like_count @user.likes.count
json.devlog_seconds_total @user.devlog_seconds_total
json.devlog_seconds_today @user.devlog_seconds_today

json.achievements @user.achievements do |user_achievement|
  achievement = user_achievement.achievement
  json.slug achievement.slug
  json.name achievement.name
  json.description achievement.description
end
