require 'dotenv'
Dotenv.load

require "./app"
require 'omniauth-twitter'
require 'warden'

failure = lambda{|e| Rack::Response.new("Can't login: #{e.inspect}", 401).finish }
Warden::Strategies.add(:twitter) do
  def valid?
    params[:twitter] or params[:oauth_token]
  end

  def authenticate!
    puts env['warden'].inspect
    key = ENV['TWITTER_KEY']
    secret = ENV['TWITTER_SECRET']

    consumer = OAuth::Consumer.new(key, secret, {:site=>"https://twitter.com"})

    if params[:oauth_token].blank?
      request_token = consumer.get_request_token :oauth_callback => callback_url
      session[:twitter] = {:token => request_token.token, :secret => request_token.secret}

      authenticate_url = request_token.authorize_url.gsub(/authorize/, 'authenticate')
      redirect!(authenticate_url)
    else
      request_token = OAuth::RequestToken.new(consumer, session[:twitter][:token], session[:twitter][:secret])
      #now we need to get an access token
      access_token =  request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])

      identifier = (access_token.params["oauth_token"] + access_token.params["oauth_token_secret"]).to_md5

      if u = User.find_by_identity_url(identifier)
        success!(u)
      else
        username = access_token.params["screen_name"]

        # Create the user
        User.create :username => username, :identity_url => identifier

        success!(u)
      end
    end
  end

  def callback_url
    uri = URI.parse(request.url)
    uri.path = '/users/twitter'
    uri.to_s
  end

end
use Warden::Manager do |manager|
  manager.default_strategies :twitter
  manager.failure_app = failure
end
use Rack::Session::Cookie, :secret => 'this is the disabuse me secret'
use OmniAuth::Strategies::Twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']


run Sinatra::Application

Warden::Manager.serialize_into_session do |user|
  puts "into session: #{user.inspect}"
  user.id
end
Warden::Manager.serialize_from_session do |id|
  puts "from session: #{id.inspect}"
  User.first_or_new({id: id})
end

