require 'sinatra'
require 'omniauth'
require 'omniauth-twitter'
require 'twitter'

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
  search_string = "@#{session[:twitter_handle]} from:#{@username}"
  @tweets = twitter.search(search_string).statuses
  haml :from_user
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