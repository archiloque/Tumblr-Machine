require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'uri'

# Api to communicate with Tumblr
class TumblrApi

  # Fetch the last images posts for a tag
  # Returns an array describing the posts
  # Note: the returned posts' tags don't include the requested tag
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
      post[:tags] = item.search('.tags a').collect { |tag| tag.content[1..-1].downcase }.uniq
      post
    end
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

  def self.tag_to_link tag, link_text = nil
    unless link_text
      link_text = tag
    end
    "<a title='View the tag' target='_blank' href='http://www.tumblr.com/tagged/#{tag.sub(' ', '+')}'>#{link_text}</a>"
  end

end