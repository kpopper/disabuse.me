require 'sinatra'
require 'haml'
require 'omniauth'
require 'omniauth-twitter'
require 'twitter'
require 'data_mapper'

use Rack::Session::Cookie, :secret => 'this is the disabuse me secret'
use OmniAuth::Builder do
  provider :developer
  provider :twitter, ENV['TWITTER_KEY'], ENV['TWITTER_SECRET']
end
# use Warden::Manager do |manager|
#   manager.serialize_into_session do |user|
#     user.id
#   end
#   manager.serialize_from_session do |id|
#     User.get id
#   end
# end
# use WardenOmniAuth do |config|
#   config.redirect_after_callback = "/"
#   Warden::Strategies[:omni_twitter].on_callback do |user|
#     # Get user info from twitter
#   end
# end

Twitter.configure do |config|
  config.consumer_key = ENV['TWITTER_KEY']
  config.consumer_secret = ENV['TWITTER_SECRET']
end

DataMapper.setup(:default, 'postgres://localhost/disabuseme_dev')

class Abuser
  include DataMapper::Resource

  property :id, Serial
  property :user_id, String
  property :username, String
  property :real_name, String
  has n, :tweets

  def set_from_twitter(twitter_user)
    self.user_id = twitter_user.id.to_s
    self.username = twitter_user.screen_name
    self.real_name = twitter_user.name
  end
end

class Tweet
  include DataMapper::Resource

  property :id, Serial
  property :tweet_id, String
  property :text, String, length: 140
  belongs_to :abuser

  def set_from_twitter(abuser, tweet)
    self.abuser = abuser
    self.tweet_id = tweet.id.to_s
    self.text = tweet.text
  end
end

DataMapper.finalize.auto_upgrade!

### ROUTES ###

get '/' do
  if session[:uid].nil?
    haml :index
  else
    haml :authed_index
  end
end

get '/from_user' do
  twitter = Twitter::Client.new(
    oauth_token: session[:oauth_token],
    oauth_token_secret: session[:oauth_token_secret]
  )

  @username = params[:username]
  abuser = Abuser.first_or_new({username: @username})
  abuser.set_from_twitter twitter.user(@username)
  abuser.save!

  search_string = "@#{session[:twitter_handle]} from:#{@username}"
  @tweets = twitter.search(search_string).statuses
  @tweets.each do |t|
    tweet = Tweet.first_or_new({tweet_id: t.id})
    tweet.set_from_twitter abuser, t
    tweet.save!
  end

  haml :from_user
end

get '/abuser/:username' do |abusername|
  @abuser = Abuser.first(username: abusername)
  haml :abuser
end

get '/auth/:provider/callback' do |provider|
  authenticate
  redirect '/'
end

private
def authenticate
  session[:uid] = auth_hash[:uid]
  session[:twitter_handle] = auth_hash[:info][:nickname]
  session[:oauth_token] = auth_hash[:credentials][:token]
  session[:oauth_token_secret] = auth_hash[:credentials][:secret]
end

def auth_hash
  request.env['omniauth.auth']
end