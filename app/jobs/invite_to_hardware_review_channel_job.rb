class InviteToHardwareReviewChannelJob < ApplicationJob
  queue_as :latency_5m

  CHANNEL_ID = Certification::Reviewable::HARDWARE_REVIEW_CHANNEL

  def perform(user)
    return if user.hardware_review_channel_invited_at.present?
    return if user.slack_id.blank?
    return if Rails.env.development?

    client = Slack::Web::Client.new(token: Rails.application.credentials.dig(:slack, :bot_token))
    client.conversations_invite(channel: CHANNEL_ID, users: user.slack_id)
    user.update_column(:hardware_review_channel_invited_at, Time.current)
  rescue Slack::Web::Api::Errors::SlackError => e
    if e.message == "already_in_channel"
      user.update_column(:hardware_review_channel_invited_at, Time.current)
    else
      Rails.logger.error("Failed to invite #{user.id} to hardware review channel: #{e.message}")
    end
  end
end
