module Sinatra

  module TumblrMachineHelper

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def display_date_time(date, between = '')
      if date
        date.strftime("%d/%m/%Y #{between}%H:%M:%S")
      end
    end

    def img_src(post, stored_images_dir)
      if post.img_saved && File.exist?(File.join(stored_images_dir, "#{post.id}#{File.extname(post.img_url)}"))
          "/stored_images/#{post.id}#{File.extname(post.img_url)}"
      else
        post.img_url
      end
    end
  end
end



