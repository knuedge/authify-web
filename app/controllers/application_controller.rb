class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :require_authentication
  #before_action :setup_munson

  layout :user_layout

  def authenticate_by_password(user, pass)
    # TODO handle auth errors
    response = RestClient.post "#{AUTHIFY_API_URL}/jwt/token",
              {'email' => user, 'password' => pass}.to_json,
              { content_type: :json, accept: :json }
    
    #session[:authenticated] = Time.now
    JSON.parse(response.body)['jwt']
  end

  def callback_url(encoded_url)
    encoded_url ? URI(Base64.decode64(encoded_url)) : callback_path
  end

  def authenticated?
    if skip_auth?
      # Don't bother with auth if we're supposed to skip it
      true
    elsif session[:last_authenticated_action] && Time.parse(session[:last_authenticated_action].to_s) > 1.hour.ago
      session[:last_authenticated_action] = Time.now
      true
    elsif session[:authenticated] && Time.parse(session[:authenticated].to_s) > 1.hour.ago
      # If they have authenticated and it hasn't expired
      session[:last_authenticated_action] = Time.now
      true
    else
      false
    end
  end

  def cached_public_key
    @cached_jwt_key ||= public_key
  end

  def public_key
    pubkey_url = URI(AUTHIFY_API_URL.dup)
    pubkey_url.path = '/jwt/key'
    # TODO handle key lookup errors
    OpenSSL::PKey::EC.new(JSON.parse(RestClient.get(pubkey_url.to_s).body)['data'])
  end

  def skip_auth?
    false
  end

  def current_user
    session[:user]
  end

  def logged_in?
    skip_auth? || (current_user && authenticated? && user?)
  end

  private

  def user?
    session[:scopes] && session[:scopes].include?('user_access')
  end

  def admin?
    session[:scopes] && session[:scopes].include?('admin_access')
  end

  def require_authentication
    unless logged_in?
      flash.now[:danger] = 'You must login to continue!'
      session[:before_login] = request.original_url
      rurl = URI(login_path)
      callback_url = AUTHIFY_PUBLIC_URL.dup
      callback_url.path = '/callback'
      rurl.query = "callback=#{Base64.encode64(callback_url.to_s).chomp}"
      redirect_to rurl.to_s
    end
  end

  def user_layout
    admin? ? 'admin' : 'application'
  end     

  def verify_token(token)
    options = {
      algorithm: Authify::Core::CONFIG[:jwt][:algorithm],
      verify_iss: true,
      verify_iat: true,
      iss: Authify::Core::CONFIG[:jwt][:issuer]
    }
    payload, _header = JWT.decode token, cached_public_key, true, options
    session[:authenticated] = Time.now
    session[:scopes] = payload['scopes']
    session[:user] = payload['user']
  end

  def setup_munson
    puts "Called `setup_munson`!"
    email = current_user ? current_user['username'] : nil
    Munson.configure(url: AUTHIFY_API_URL.to_s, response_key_format: :dasherize) do |c|
      c.use Middleware::AuthifyTrustedDelegate, email: email
    end
  end
end
