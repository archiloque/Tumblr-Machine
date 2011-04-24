require 'nokogiri'
require 'open-uri'

class TumblrApi

  def self.fetch_tag tag_name
    url = "http://www.tumblr.com/tagged/#{tag_name.sub(' ', '+')}"
    doc = Nokogiri::HTML(open(url))
    doc.search('#posts > .photo').collect do |item|
      post = {}

      post_id = item[:id]
      post[:id] = post_id[(post_id.rindex('_') +1) .. -1].to_i

      post_info = item.search('.post_info a')[0]
      post[:tumblr_name] = post_info.content
      post[:tumblr_url] = post_info[:href]
      post[:tags] = item.search('.tags a').collect{|tag| tag.content[1..-1].downcase}.uniq
      post
    end
  end

end