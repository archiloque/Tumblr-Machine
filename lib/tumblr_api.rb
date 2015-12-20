require 'addressable/uri'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'typhoeus'
require 'json'

# Api to communicate with Tumblr
class TumblrApi

  # Fetch the last images posts for a list of tags
  # Note: the the found tags are normalized (lower case and uniq)
  # @return [Hash] list of posts
  def self.fetch_tags(api_key, tags_names, &block)
    semaphore = Mutex.new
    posts = []
    hydra = Typhoeus::Hydra.new({:max_concurrency => 4})
    tags_names.each do |tag_name|
      url = "http://api.tumblr.com/v2/tagged?api_key=#{api_key}&tag=#{tag_name.sub(' ', '+')}"
      request = Typhoeus::Request.new url
      request.on_complete do |response|
        if response.code == 200
          JSON.parse(response.body)['response'].each do |item|
            begin
              post = {
                  :id => item['id'],
                  :reblog_key => item['reblog_key'],
                  :tumblr_name => item['blog_name'],
                  :tags => (item['tags'] + [tag_name]).collect { |tag| tag.downcase }.uniq,
                  :tumblr_url => "http://#{Addressable::URI.parse(item['post_url']).host}"
              }

              if item['photos']
                photo = item['photos'].first['alt_sizes'].find { |photo| photo['width'] <= 500 } || item['photos'].first['original_size']
                post[:img_url] = photo['url']
                post[:width] = photo['width']
                post[:height] = photo['height']
              end
              semaphore.synchronize do
                posts << post
              end
            rescue Exception => e
              p e
            end
          end
        end
      end
      hydra.queue request
    end
    hydra.run
    posts
  end

  # Get the reblog key of a post to be able to reblog it
  # Parameters:
  # - tumblr_name the name of the tumblr containing the post
  # - post_id    the post id
  def self.reblog_key(api_key, tumblr_name, post_id)
    url = "http://api.tumblr.com/v2/blog/#{tumblr_name}.tumblr.com/posts/?api_key=#{api_key}&id=#{post_id}&reblog_info=true"
    JSON.parse(open(url).string)['response']['posts'][0]['reblog_key']
  end

  # Reblog a post
  # Parameters:
  # - access_token the oauth access token
  # - tumblr     the user tumblr
  # - post_id    the id of the post to reblog
  # - reblog_key the reblog key of the post to reblog
  # - date       the date to post
  def self.reblog(access_token, tumblr_name, post_id, reblog_key)
    params = {
        'id' => post_id,
        'reblog_key' => reblog_key
    }
    access_token.post("http://api.tumblr.com/v2/blog/#{tumblr_name}.tumblr.com/post/reblog", params)
  end

  # Create a link to a tag
  # Parameters:
  # - tag       the tag name
  # - link_text the link text, if null use the tag name
  def self.tag_to_link tag, link_text = tag
    "<a title='View the tag' target='_blank' href='http://www.tumblr.com/tagged/#{tag.sub(' ', '+')}'>#{link_text}</a>"
  end

end