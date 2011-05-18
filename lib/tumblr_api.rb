require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'uri'
require 'typhoeus'

# Api to communicate with Tumblr
class TumblrApi

  # Fetch the last images posts for a list of tags
  # Returns an array describing the posts
  # Note: the the found tags are normalized (lower case and uniq)
  def self.fetch_tags tags_names
    posts = []
    hydra = Typhoeus::Hydra.new
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

            image = item.at('.image_thumbnail')
            if image
              post[:img_url] = image[:src]
              post[:width] = image[:width]
              post[:height] = image[:height]
            end

            post_info = item.at('.post_info a')
            post[:tumblr_name] = post_info.content
            post[:tumblr_url] = post_info[:href]

            post[:tags] = [tag_name].concat(item.search('.tags a').collect { |tag| tag.content[1..-1].downcase }.uniq)
            posts << post
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
  # - tumblr_url the url of the tumblr containing the post
  # - post_id    the post id
  def self.reblog_key tumblr_url, post_id
    url = "#{tumblr_url}/api/read/?id=#{post_id}"
    doc = Nokogiri::HTML(open(url))
    doc.search('post')[0]['reblog-key']
  end

  # Reblog a post
  # Parameters:
  # - email      the user email
  # - password   the user password
  # - tumblr     the user tumblr
  # - post_id    the id of the post to reblog
  # - reblog_key the reblog key of the post to reblog
  # - date       the date to post
  def self.reblog email, password, tumblr, post_id, reblog_key, tags = nil, date = nil
    params = {'email' => email,
              'password' => password,
              'group' => "#{tumblr}.tumblr.com",
              'post-id' => post_id,
              'reblog-key' => reblog_key,
              'generator' => 'Tumblr Machine'}
    if tags
      params['tags'] = tags.join(',')
    end
    if date
      params['state'] = 'queue'
      params['publish-on'] = date.to_s
    end
    Net::HTTP.post_form(URI.parse("http://www.tumblr.com/api/reblog"), params)
  end

  # Create a link to a tag
  # Parameters:
  # - tag       the tag name
  # - link_text the link text, if null use the tag name
  def self.tag_to_link tag, link_text = tag
    "<a title='View the tag' target='_blank' href='http://www.tumblr.com/tagged/#{tag.sub(' ', '+')}'>#{link_text}</a>"
  end

end