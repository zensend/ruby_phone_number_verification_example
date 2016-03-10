require 'sinatra'
require 'sinatra/flash'
require "sinatra/config_file"

require "sinatra/reloader" if development?

require 'zensend'
require 'redis'
require 'uri'

require './lib/util'

config_file 'config.yml'

REDIS_EXPIRE_TIME = 60 * 5 # 5 minutes
MAX_ATTEMPTS = 3

REDIS_CONNECTION = Redis.new(url: settings.redis_url)

enable :sessions

set :secret, settings.respond_to?(:secret_key) ? settings.secret_key : SecureRandom.hex(16)

get '/success' do
  @msisdn = session['verified_msisdn']

  if @msisdn.nil?
    flash[:error] = "You must verify your msisdn first"

    return redirect "/verify_number"
  end

  erb :success
end

get '/verify_number' do
  @error = flash[:error]

  erb :verify_number
end

get '/verify_token' do
  @error = flash[:error]

  erb :verify_token
end

post '/verify_token' do
  msisdn_token = session['msisdn_token']

  if msisdn_token.nil?
    flash[:error] = "You must send yourself a token first"

    return redirect "/verify_number"
  end

  @token = params[:token]

  current_token, current_attempts, msisdn = REDIS_CONNECTION.hmget(msisdn_token, "token", "attempts", "msisdn")

  if current_token.nil?
    flash[:error] = "Send yourself a token first"

    return redirect "/verify_number"
  end

  attempts = REDIS_CONNECTION.hincrby(msisdn_token, "attempts", 1)

  if attempts > MAX_ATTEMPTS
    @error = "Maximum attempts"

    return erb :verify_token
  end

  if Util.secure_compare(current_token, @token)
    REDIS_CONNECTION.del(msisdn_token)

    session['verified_msisdn'] = msisdn

    return redirect "/success"
  end

  @error = attempts >= MAX_ATTEMPTS ? "Maximum attempts" : "Invalid token"

  erb :verify_token
end

post '/verify_number' do
  msisdn = params[:msisdn]

  msisdn_token = SecureRandom.hex(16)
  sms_token = Util.secure_random_between(100_000, 999_999 + 1)

  REDIS_CONNECTION.hmset(msisdn_token, "token", sms_token, "attempts", 0, "msisdn", msisdn)
  REDIS_CONNECTION.expire(msisdn_token, REDIS_EXPIRE_TIME)

  client = ZenSend::Client.new(settings.zensend_api_key)

  begin
    client.send_sms({
      originator: "VERIFY",
      body: sms_token,
      numbers: [msisdn]
    })

    session['msisdn_token'] = msisdn_token

    redirect "/verify_token"
  rescue ZenSend::ZenSendException => e
    @error = "Error sending token"

    erb :verify_number
  end
end

