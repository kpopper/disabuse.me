require 'sinatra'
require 'haml'
require 'twitter'
require 'data_mapper'

Twitter.configure do |config|
  config.consumer_key = ENV['TWITTER_KEY']
  config.consumer_secret = ENV['TWITTER_SECRET']
end

DataMapper.setup(:default, 'postgres://localhost/disabuseme_dev')

class User
  include DataMapper::Resource
  
  property :id, Serial
  property :username, String
  property :identity_url, String
end

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
  haml :index
end

get '/home' do
  env['warden'].authenticate!
  haml :authed_index
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
  #authenticate
  redirect '/home'
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

def current_user
  env['warden'].user
end