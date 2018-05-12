class DiscourseAdapter
  attr_reader :client

  def initialize
    @client = DiscourseApi::Client.new("https://forum.ruby.org.au")
    @client.api_key = ENV['DISCOURSE_KEY']
    @client.api_username = ENV['DISCOURSE_USERNAME']
  end

  def create_topic(*args)
    with_wait do
      puts 'Creating discourse topic '.green + args.inspect
      client.create_topic(*args)
    end
  end

  def create_post(*args)
    with_wait do
      puts 'Posting to discourse '.green + args.inspect
      client.create_post(*args)
    end
  end

  def topic(*args)
    with_wait do
      puts 'Checking discourse topic '.green + args.inspect
      client.topic(*args)
    end
  end

  def edit_post(*args)
    with_wait do
      puts 'Editing discourse post '.green + args.inspect
      client.edit_post(*args)
    end
  end

  def with_wait
    yield
  rescue DiscourseApi::TooManyRequests => e
    seconds = eval(e.message)['extras']['wait_seconds'] + 1
    puts "Too many requests, sleeping #{seconds} seconds ...".blue

    sleep eval(e.message)['extras']['wait_seconds'] + 1
    retry
  end
end
