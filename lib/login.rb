# session management
class TumblrMachine

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
    if (!ENV['openid_uri']) || @user_logged
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
end