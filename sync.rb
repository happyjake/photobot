#! /bin/env ruby
require 'flickraw-cached'
require "json"
require 'pathname'
require 'micro-optparse'

options = Parser.new do |p|
   p.banner = "sync photo dirs to flickr"
#   p.option :title, "photo title", :default => ""
end.process!

APP_ROOT = File.expand_path(File.dirname(Pathname.new(__FILE__).realpath))

conf = JSON.parse( IO.read("#{APP_ROOT}/config.json") )

FlickRaw.api_key=conf['api_key']
FlickRaw.shared_secret=conf['api_secret']

flickr.access_token = conf['access_token']
flickr.access_secret = conf['access_secret']

root_dir = conf['root_dir']

if root_dir.length == 0
  abort 'no root_dir in conf file'
end

puts "root #{root_dir}"

# You need to be authentified to do that, see the previous examples.
Dir.chdir(root_dir) do
  Dir['*'].each do |d|
    puts "for #{d}"
    c = {'done' => {}}
    cpath = "#{d}/config.json"
    if File.exist? cpath
      c = JSON.parse( IO.read("#{d}/config.json") )
    end
    Dir.glob("#{d}/*.{jpg,jpeg,png,gif}",File::FNM_CASEFOLD).sort_by {|s| s.match(/(\d+)\.(jpg|jpeg|png|gif)/i)[1].to_i }.each do |f|
      bf = (Pathname.new(f).relative_path_from Pathname.new(d)).to_s
      if c['done'].has_key? bf
        puts "skip #{f}"
        next
      end
      puts "uploading #{f}"
      photoID = flickr.upload_photo f, :is_public => 0 , :is_friend => 0 , :is_family => 0 , :hidden => 2
      if photoID
        c['done'][bf] = photoID
        # create photo set if not exist
        if not c['set_id']
          # create and add to set
          puts "creating photo set #{d}"
          s = flickr.photosets.create :title => d, :primary_photo_id => photoID
          c['set_id'] = s.id
          c['set_url'] = s.url
        else 
          # add to set
          puts "adding to set #{d}"
          flickr.photosets.addPhoto :photoset_id => c['set_id'], :photo_id => photoID
        end
        IO.write("#{d}/config.json",JSON.pretty_generate(c))
      else 
        puts "failed #{f}"
      end
    end
  end
end
