class MeetupAdapter
  attr_reader :client

  def initialize
    @client = MeetupAdapter::Client.new
  end

  def events(group_id, params = {})
    Rails.cache.fetch([:meetup, :events, group_id], expires_in: 12.hours) do
      puts 'Fetching meetup events '.green + group_id + ' ' + params.inspect
      client.events(group_id, params)
    end
  end

  def comments(group_id, event_id)
    puts 'Fetching meetup comments '.green + "#{group_id} #{event_id}"
    client.comments(
      url_name: group_id,
      event_id: event_id
    )
  end

  def post_comment(group_id, event_id, params)
    puts 'Posting comment to meetup '.green + "#{group_id} #{event_id} " + params.inspect
    client.post_comment(
      url_name: group_id,
      event_id: event_id,
      params: params
    )
  end

  class Client
    attr_reader :session
    attr_reader :key

    def initialize
      @key = ENV['MEETUP_KEY']
      @session = Excon.new('https://api.meetup.com/')
    end

    def events(url_name, params)
      parse session.get(
        path: "/#{url_name}/events",
        query: with_key(params)
      )
    end

    def comments(url_name:, event_id:, params: {})
      parse session.get(
        path: "/#{url_name}/events/#{event_id}/comments",
        query: with_key(params)
      )
    end

    def post_comment(url_name:, event_id:, params:)
      parse session.post(
        path: "/#{url_name}/events/#{event_id}/comments",
        query: with_key(params)
      )
    end

    def parse(value)
      JSON.parse value.body
    end

    def with_key(params = {})
      params.merge(key: key)
    end
  end
end
