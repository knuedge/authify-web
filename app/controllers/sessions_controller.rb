class SessionsController < ApplicationController
  skip_before_action :setup_munson
  layout 'minimal'

  def new
    @callback_url = callback_url(params[:callback])
  end

  def create
    token = authenticate_by_password(params[:session][:email], params[:session][:password])
    if token
      rurl = URI(params[:session][:callback])
      rurl.query = rurl.query ? rurl.query + "jwt=#{token}" : "jwt=#{token}"
      redirect_to rurl.to_s
    else
      flash.now[:danger] = 'Invalid login/password combination'
      render 'new'
    end
  end

  def signup
    @callback_url = callback_url(params[:callback])
  end

  def register
    email = params[:registration][:email]
    name = params[:registration][:name]
    password = params[:registration][:password]

    token = User.register(email, name, password)
    if token
      rurl = URI(params[:registration][:callback])
      rurl.query = rurl.query ? rurl.query + "jwt=#{token}" : "jwt=#{token}"
      redirect_to rurl.to_s
    else
      raise 'Registration Failed'
    end
  end

  def callback
    verify_token params[:jwt]
    next_path = session[:before_login]
    session.delete(:before_login)
    redirect_to next_path
  end

  def destroy
    reset_session
    flash[:alert] = 'You have been logged out'
    redirect_to login_path
  end

  private

  def skip_auth?
    !['destroy'].include? action_name
  end
end
