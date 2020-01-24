# frozen_string_literal: true

class PublishAnnouncementReactionWorker
  include Sidekiq::Worker
  include Redisable

  def perform(announcement_id, name)
    announcement = Announcement.find(announcement_id)

    reaction,  = announcement.announcement_reactions.where(name: name).group(:announcement_id, :name, :custom_emoji_id).select('name, custom_emoji_id, count(*) as count, false as me')
    reaction ||= announcement.announcement_reactions.new(name: name)

    payload = InlineRenderer.render(reaction, nil, :reaction).tap { |h| h[:announcement_id] = announcement_id }
    payload = Oj.dump(event: :'announcement.reaction', payload: payload)

    Account.joins(:user).where('users.current_sign_in_at > ?', User::ACTIVE_DURATION.ago).find_each do |account|
      redis.publish("timeline:#{account.id}", payload) if redis.exists("subscribed:timeline:#{account.id}")
    end
  rescue ActiveRecord::RecordNotFound
    true
  end
end
