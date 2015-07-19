#! /bin/env ruby
require 'flickraw'
require "json"

APP_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '.'))
DATA_ROOT = '/data/photos'

conf = JSON.parse( IO.read("#{DATA_ROOT}/config.json") )

FlickRaw.api_key=conf['api_key']
FlickRaw.shared_secret=conf['api_secret']

puts "get token"
token = flickr.get_request_token
puts "get url"
auth_url = flickr.get_authorize_url(token['oauth_token'], :perms => 'delete')

puts "Open this url in your process to complete the authication process : "
puts "#{auth_url}"
puts "Copy here the number given when you complete the process."
verify = gets.strip

begin
  flickr.get_access_token(token['oauth_token'], token['oauth_token_secret'], verify)
  login = flickr.test.login
  puts "You are now authenticated as #{login.username} with token #{flickr.access_token} and secret #{flickr.access_secret}"
  conf['access_token'] = flickr.access_token
  conf['access_secret'] = flickr.access_secret
  IO.write("#{DATA_ROOT}/config.json",JSON.pretty_generate(conf))
  puts "saved to #{DATA_ROOT}/config.json"
rescue FlickRaw::FailedResponse => e
  puts "Authentication failed : #{e.msg}"
end
