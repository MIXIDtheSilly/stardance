json.extract! user, :id, :slack_id, :display_name

json.avatar user.avatar
json.project_ids user.projects.map(&:id)
json.stardust user.stardust_for(viewer)
