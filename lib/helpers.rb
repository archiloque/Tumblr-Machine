module Sinatra

  module TumblrMachineHelper
    def h(text)
      Rack::Utils.escape_html(text)
    end

    def display_date_time date, between = ''
      if date
        date.strftime("%d/%m/%Y #{between}%H:%M:%S")
      end
    end

  end
end



