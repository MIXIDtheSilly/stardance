class AddHardwareReviewChannelInvitedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hardware_review_channel_invited_at, :datetime
  end
end
