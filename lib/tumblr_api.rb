require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'uri'
require 'typhoeus'
require 'json'

# Api to communicate with Tumblr
class TumblrApi

  # parse the javascript of the onclick property of the image to get info of the large version
  IMAGE_SIZE_REGEX = /.*this.src='([^']*)'.*else.*width.*'(\d*)px'.*height.*'(\d*)px'.*/m

  # Fetch the last images posts for a list of tags
  # Call the block with the image a parameter
  # Note: the the found tags are normalized (lower case and uniq)
  def self.fetch_tags tags_names, &block
    hydra = Typhoeus::Hydra.new({:max_concurrency => 4})
    hydra.disable_memoization
    tags_names.each do |tag_name|
      url = "http://www.tumblr.com/tagged/#{tag_name.sub(' ', '+')}"
      request = Typhoeus::Request.new url
      request.on_complete do |response|
        if response.code == 200
          doc = Nokogiri::HTML(response.body)
          doc.search('#posts > .photo').each do |item|
            post = {}
            post_id = item[:id]
            post[:id] = post_id[(post_id.rindex('_') +1) .. -1].to_i

            image = item.at('.image')
            if image
              # try to get the large image info from the javascript
              if r = IMAGE_SIZE_REGEX.match(image[:onclick])
                post[:img_url] = r[1]
                post[:width] = r[2].to_i
                post[:height] = r[3].to_i
              else
                # failed: get the info of the small image
                post[:img_url] = image[:src]
                post[:width] = image[:width]
                post[:height] = image[:height]
              end
            end

            post_info = item.at('.post_info a')
            post[:tumblr_name] = post_info.content
            post[:tumblr_url] = post_info[:href]

            post[:tags] = [tag_name].concat(item.search('.tags a').collect { |tag| tag.content[1..-1].downcase }.uniq)
            block.call post
          end
        end
      end
      hydra.queue request
    end
    hydra.run
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
  # - access_token the oath access token
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