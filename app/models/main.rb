class Main
  def run
    meetups = [
      {urlname: 'adelaiderb'},
      {urlname: 'brisRuby'},
      {urlname: 'canberra-ruby'},
      {urlname: 'Ruby-On-Rails-Oceania-Melbourne'},
      {urlname: 'roro-perth'},
      {urlname: 'Ruby-On-Rails-Oceania-Sydney'},
    ]

    meetups.each do |info|
      sync_meetup(info[:urlname])
    end
  end

  def sync_meetup(meetup_urlname)
    meetup_events = MeetupAdapter.new.events(meetup_urlname, status: 'past,upcoming')

    events = meetup_events
      .map { |meetup_event| create_event_from_meetup(meetup_event) }

    events.select! do |event|
      event.meetup_at >= 2.weeks.ago && event.meetup_at < 2.weeks.from_now
    end

    # POST EVENTS TO DISCOURSE
    events.each do |event|
      next if event.discourse_updated_at && event.discourse_updated_at > 12.hours.ago

      if event.discourse_topic_id.blank?
        post_new_event_to_discourse(event)
      else
        update_topic(event)
      end
    end

    # POST COMMENTS TO DISCOURSE
    events.each do |event|
      meetup_comments = MeetupAdapter.new
        .comments(event.meetup_urlname, event.meetup_event_id)

      comments = meetup_comments
        .map { |comment_info| assign_meetup_comment(event, comment_info) }
        .flatten

      comments
        .select { |comment| comment.discourse_comment_id.blank? }
        .sort_by(&:meetup_created_at)
        .each { |comment| comment.post_to_discourse }
    end

    # POST COMMENTS TO MEETUP
    events.each do |event|
      discourse_topic = DiscourseAdapter.new.topic(event.discourse_topic_id)

      comments = discourse_topic['post_stream']['posts'].map do |discourse_post|
        next if discourse_post['post_number'] == 1
        next if discourse_post['post_type'] != 1 # 1 is regular

        comment = Comment.find_by(discourse_comment_id: discourse_post['id']) || Comment.new
        comment.event = event
        comment.discourse = discourse_post
        comment.save!
        comment
      end.compact

      comments.each do |comment|
        if comment.meetup_comment_id.blank?
          comment.post_to_meetup
        end
      end
    end

    nil
  end

  def update_topic(event)
    response = DiscourseAdapter.new.edit_post(
      event.discourse_post_id,
      event.discourse_topic_body
    )

    event.discourse_json_data = response.body['post']
    event.discourse_updated_at = Time.now
    event.save!
  end

  def post_new_event_to_discourse(event)
    discourse_topic = DiscourseAdapter.new.create_topic(
      title: event.discourse_topic_title,
      raw: event.discourse_topic_body,
      category: 'Events'
    )

    event.discourse_topic_id = discourse_topic['topic_id']
    event.discourse_json_data = discourse_topic
    event.discourse_updated_at = Time.now

    event.save!
  end

  def assign_meetup_comment(event, meetup_comment)
    comment = Comment.find_by(meetup_comment_id: meetup_comment['id']) || Comment.new

    comment.event = event
    comment.meetup = meetup_comment
    comment.save!

    replies = meetup_comment.fetch 'replies', []
    replies.map do |reply_info|
      assign_meetup_comment(event, reply_info)
    end + [comment]
  end

  def create_event_from_meetup(meetup_event)
    meetup_event_id = meetup_event['id']
    event = Event.find_by(meetup_event_id: meetup_event_id) ||
      Event.new(meetup_event_id: meetup_event_id)

    event.meetup_json_data = meetup_event
    event.meetup_urlname = meetup_event['group']['urlname']
    event.meetup_at = Time.at(meetup_event['time'] / 1000)

    event.save!
    event
  end
end
