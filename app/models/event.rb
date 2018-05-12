# == Schema Information
#
# Table name: events
#
#  id                  :integer          not null, primary key
#  discourse_topic_id  :string
#  discourse_json_data :jsonb
#  meetup_at           :datetime
#  meetup_event_id     :string
#  meetup_urlname      :string
#  meetup_json_data    :jsonb
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class Event < ApplicationRecord
  has_many :comments

  def discourse_post_id
    discourse_json_data['id']
  end

  def discourse_topic_title
    h = meetup_json_data

    city = h['group']['localized_location'].split(',').first

    [
      h['local_date'].gsub('-', '.'),
      h['local_time'],
      '[' + city + ']',
      h['name'],
    ].join(' ')
  end

  def discourse_topic_body
    h = meetup_json_data

    where = ''
    if h['venue']
      link_params = {
        q: [
          h['venue']['address_1'],
          h['venue']['city'],
          h['venue']['country']
        ].join(' ')
      }
      link = "https://www.google.com/maps/?#{link_params.to_query}"

      where = "**Where:** #{h['venue']['name']} - [#{h['venue']['address_1']}, #{h['venue']['city']}](#{link})"
    end

    date = Date.parse(h['local_date']).to_s(:long)

    <<~TXT
      ## #{h['name']}
      
      **When:** #{date} at #{h['local_time']}
      #{where}
      **RSVPs:** #{h['yes_rsvp_count']}

      #{h['description']}
  
      #{h['link']}

      _Note: replies in this topic are synchronized with the meetup event comments_
    TXT
  end
end
