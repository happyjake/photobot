#!/usr/bin/ruby 
require 'flickraw-cached'
require "json"
require 'pathname'
require 'micro-optparse'
require 'logger'
require 'exifr'

APP_ROOT = File.expand_path(File.dirname(Pathname.new(__FILE__).realpath))
DATA_ROOT = '/data/photos'

class Object
  def as
    yield self
  end
end

def humanize (x)
  i = 0
  while x > 1024
    i += 1
    x /= 1024.0
    end
  "#{'%.2f' % x}#{'BKMGT'.chars.to_a[i]}"
end

def main
  options = Parser.new do |p|
     p.banner = "sync photo dirs to flickr"
  #   p.option :title, "photo title", :default => ""
  end.process!
  
  Dir.mkdir("#{DATA_ROOT}/logs") unless File.exist?("#{DATA_ROOT}/logs")
  log = Logger.new( "#{DATA_ROOT}/logs/sync.log", 'monthly' )
  log.level = Logger::INFO
  
  $stdout.reopen("#{DATA_ROOT}/logs/sync.log", "a+")
  $stdout.sync = true
  $stderr.reopen($stdout)
  
  log.info "app started"
  
  conf = JSON.parse( IO.read("#{DATA_ROOT}/config.json",:encoding => 'utf-8') )
  
  FlickRaw.api_key=conf['api_key']
  FlickRaw.shared_secret=conf['api_secret']
  
  flickr.access_token = conf['access_token']
  flickr.access_secret = conf['access_secret']
  
  root_dir = DATA_ROOT
  
  if root_dir.length == 0
    abort 'no root_dir'
  end
  
  log.info "root #{root_dir}"
  
  # main
  Dir.chdir(root_dir) do
    Dir['*'].each do |d|
      if not File.directory?(d)
        next
      end
      log.debug "for #{d}"
      c = {'done' => {},'unset' => []}
      cpath = "#{d}/config.json"
      if File.exist? cpath
        c = JSON.parse( IO.read("#{d}/config.json",:encoding => 'utf-8') )
        c['unset'] = [] if not c.has_key? 'unset'
      end

      save_conf = lambda {
        IO.write("#{d}/config.json",JSON.pretty_generate(c))
      }

      add_to_set = lambda {|photoID| 
        # create photo set if not exist
        if not c['set_id']
          # create and add to set
          log.info "creating photo set #{d}"
          s = flickr.photosets.create :title => d, :primary_photo_id => photoID
          c['set_id'] = s.id
          c['set_url'] = s.url
          c['unset'].delete(photoID)
        else 
          # add to set
          log.info "adding to set #{d}"
          flickr.photosets.addPhoto :photoset_id => c['set_id'], :photo_id => photoID
          c['unset'].delete(photoID)
        end
        save_conf.call
      }
     
      upload_photo = lambda {|f,bf| 
        log.info "uploading #{f} (size #{humanize(File.stat(f).size)})"
        photoID = flickr.upload_photo f, :is_public => 0 , :is_friend => 0 , :is_family => 0 , :hidden => 2
        if photoID
          c['done'][bf] = photoID
          c['unset'].push(photoID)
          save_conf.call
        end
        photoID
      }

      # add unset to set
      while c['unset'].length > 0 
        photoID = c['unset'][0]
        add_to_set.call(photoID)
      end

      # find all image and video
      Dir.glob("#{d}/*.{jpg,jpeg,png,gif,mp4,m4v,mov}",File::FNM_CASEFOLD).sort_by {|s| 
        # EXIFR::JPEG.new(s).date_time
        File.stat(s).as {|x| [x.ctime,x.mtime].min}
      }.each do |f|
        # relative path
        bf = (Pathname.new(f).relative_path_from Pathname.new(d)).to_s

        # uploaded?
        if c['done'].has_key? bf
          log.debug "skip #{f}"
          next
        end
 
        # upload
        photoID = upload_photo.call(f,bf)

        # add to set
        if photoID and photoID.is_a? String
          add_to_set.call(photoID)
        else 
          log.info "failed #{f}"
        end
      end
    end
  end
end

begin
  main
  puts "normal exit."
rescue => e
  puts e
  raise e
end
