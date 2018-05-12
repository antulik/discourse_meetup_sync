# == Schema Information
#
# Table name: comments
#
#  id                             :integer          not null, primary key
#  event_id                       :integer
#  discourse_comment_id           :integer
#  discourse_post_number          :integer
#  discourse_reply_to_post_number :integer
#  discourse_json_data            :jsonb
#  meetup_created_at              :datetime
#  meetup_comment_id              :integer
#  meetup_in_reply_to             :integer
#  meetup_json_data               :jsonb
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#

class Comment < ApplicationRecord
  belongs_to :event

  def discourse=(discourse_post)
    self.discourse_comment_id = discourse_post['id']
    self.discourse_post_number = discourse_post['post_number']
    self.discourse_reply_to_post_number = discourse_post['reply_to_post_number']
    self.discourse_json_data = discourse_post
  end

  def meetup=(meetup_comment)
    self.meetup_created_at = Time.at(meetup_comment['created'] / 1000)
    self.meetup_comment_id = meetup_comment['id']
    self.meetup_in_reply_to = meetup_comment['in_reply_to']
    self.meetup_json_data = meetup_comment
  end

  def post_to_discourse
    h = meetup_json_data
    quote = ''

    if meetup_in_reply_to
      reply_to_comment = Comment.find_by(meetup_comment_id: meetup_in_reply_to)
      rh = reply_to_comment.meetup_json_data

      quote = <<~MSG
        [quote="#{rh['member']['name']}, post:#{reply_to_comment.discourse_post_number}, topic:#{event.discourse_topic_id}"]
         #{rh['comment']}
        [/quote]
      MSG
    end

    img_src = h.dig('member', 'photo', 'thumb_link')
    img = if img_src
      "<img src=\"#{h['member']['photo']['thumb_link']}\" height=40>"
    end

    text = <<~MSG
      #{quote}
      #{img} [**#{h['member']['name']}**](#{h['link']})

      #{h['comment']}
    MSG

    discourse_post = DiscourseAdapter.new.create_post(
      topic_id: event.discourse_topic_id,
      raw: text,
      created_at: Time.at(h['created'] / 1000).to_date.iso8601 # probably not working
    )

    self.discourse = discourse_post
    save!
  end

  def post_to_meetup
    text = discourse_json_data['cooked']
    text = text.gsub('</p>', "</p>\n\n")
    text = ActionController::Base.helpers.sanitize(text, tags: [], attributes: [])
    text = discourse_json_data['name'] + ":\n" + text

    footer = "-- https://forum.ruby.org.au/t/#{event.discourse_topic_id}/#{discourse_post_number}"

    max_meetup_comment_length = 1024
    text_size = max_meetup_comment_length - footer.size
    text = text.first(text_size) + footer

    params = {
      comment: text,
      notifications: false,
    }

    if discourse_reply_to_post_number
      reply_to_comment = Comment.find_by(discourse_post_number: discourse_reply_to_post_number)
      params[:in_reply_to] = reply_to_comment.meetup_comment_id
      # todo: strip quoted text
    end

    meetup_comment = MeetupAdapter.new.post_comment(event.meetup_urlname, event.meetup_event_id, params)
    self.meetup = meetup_comment
    save!
  end
end
