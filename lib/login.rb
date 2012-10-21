require 'oauth'

# session management
class TumblrMachine

  get '/callback' do
    request_token=session[:request_token]
    @access_token = request_token.get_access_token({:oauth_verifier => params[:oauth_verifier]})
    session[:access_token] = @access_token
    Meta.create(:key => 'access_token_token', :value => @access_token.token)
    Meta.create(:key => 'access_token_secret', :value => @access_token.secret)
    redirect '/'
  end

  get '/login' do
    if resp = request.env['rack.openid.response']
      if resp.status == :success
        session[:user] = resp
        redirect '/'
      else
        halt 404, "Error: #{resp.status}"
      end
    elsif ENV['openid_uri']
      openid_params = {:identifier => ENV['openid_uri']}
      if params[:return_to]
        openid_params[:return_to] = params[:return_to]
      end
      headers 'WWW-Authenticate' => Rack::OpenID.build_header(openid_params)
      halt 401, 'got openid?'
    else
      redirect '/'
    end
  end

  private

  def check_logged
    if !@access_token
      oauth_process
    elsif (!ENV['openid_uri']) || @user_logged
    elsif resp = request.env['rack.openid.response']
      if resp.status == :success
        session[:user] = resp
      else
        halt 404, "Error: #{resp.status}"
      end
    else
      redirect "/login?return_to=#{CGI::escape(request.url)}"
      halt
    end
  end

  def check_logged_ajax
    unless (!ENV['openid_uri']) || @user_logged
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