require 'oauth'

# session management
class TumblrMachine

  get '/callback' do
    request_token = session[:request_token]
    @access_token = request_token.get_access_token({:oauth_verifier => params[:oauth_verifier]})
    session[:access_token] = @access_token
    create_or_update_meta('access_token_token', @access_token.token)
    create_or_update_meta('access_token_secret', @access_token.secret)
    redirect '/'
  end

  private

  def create_or_update_meta(key, value)
    if Meta.where({:key => key}).exists
      Post.where({:key => value}).update({:value => value})
    else
      Meta.create(:key => key, :value => value)
    end
  end

  def check_logged
    if !@access_token
      oauth_process
    elsif (!ENV['http_x_ssl_issuer']) || @user_logged
    elsif request.env['HTTP_X_SSL_ISSUER'] == ENV['http_x_ssl_issuer']
      session[:user] = request.env['HTTP_X_SSL_ISSUER']
    else
      redirect '/'
      halt
    end
  end

  def check_logged_ajax
    unless (!ENV['http_x_ssl_issuer']) || @user_logged
      body 'Logged users only'
      halt
    end
  end

  def oauth_process
    request_token = @consumer.get_request_token(:oauth_callback => "#{request.scheme}://#{request.host_with_port}/callback")
    session[:request_token] = request_token
    redirect request_token.authorize_url
  end

end