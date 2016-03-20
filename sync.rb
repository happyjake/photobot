#!/usr/bin/ruby 
require 'flickraw-cached'
require "json"
require 'pathname'
require 'micro-optparse'
require 'logger'
require 'exifr'
require 'time'

APP_ROOT = File.expand_path(File.dirname(Pathname.new(__FILE__).realpath))
DATA_ROOT = '/data/photos'

DOING = 'doing'
DONE = 'done'
UNSET = 'unset'
SET_ID = 'set_id'
SET_URL = 'set_url'
FAIL_COUNT = 'fail_count'
LAST_UPLOAD_TIME = 'last_upload_time'

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
      if not File.directory?(d) or d == 'logs'
        next
      end
      log.debug "for #{d}"
      c = { DONE => {}, UNSET => []}
      cpath = "#{d}/config.json"
      if File.exist? cpath
        c = JSON.parse( IO.read("#{d}/config.json",:encoding => 'utf-8') )
        c[UNSET] = [] if not c.has_key? UNSET
      end

      save_conf = lambda {
        IO.write("#{d}/config.json",JSON.pretty_generate(c))
      }

      add_to_set = lambda {|photoID| 
        # create photo set if not exist
        if not c[SET_ID]
          # create and add to set
          log.info "creating photo set #{d}"
          s = flickr.photosets.create :title => d, :primary_photo_id => photoID
          c[SET_ID] = s.id
          c[SET_URL] = s.url
          c[UNSET].delete(photoID)
        else 
          # add to set
          log.info "adding to set #{d}"
          flickr.photosets.addPhoto :photoset_id => c[SET_ID], :photo_id => photoID
          c[UNSET].delete(photoID)
        end
        save_conf.call
      }
     
      upload_photo = lambda {|f,bf| 
        log.info "uploading #{f} (size #{humanize(File.stat(f).size)})"

        c[DOING][bf][FAIL_COUNT] = c[DOING][bf][FAIL_COUNT] + 1
        c[DOING][bf][LAST_UPLOAD_TIME] = "#{Time.now}"
        save_conf.call

        photoID = flickr.upload_photo f, :is_public => 0 , :is_friend => 0 , :is_family => 0 , :hidden => 2
        if photoID
          c[DONE][bf] = photoID
          c[UNSET].push(photoID)
          c[DOING].delete(bf)
          save_conf.call
        end
        photoID
      }

      # add unset to set
      while c[UNSET].length > 0 
        yhotoID = c[UNSET][0]
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
        if c[DONE].has_key? bf
          log.debug "skip #{f}"
          next
        end
 
        # try count. or skip files that always fail.
        c[DOING] = {} if not c.has_key? DOING
        c[DOING][bf] = { FAIL_COUNT => 0, LAST_UPLOAD_TIME => '' } if not c[DOING].has_key? bf

        if c[DOING][bf][FAIL_COUNT] >= 3
          # retry one more time every 3 days
          if Time.now - Time.parse(c[DOING][bf][LAST_UPLOAD_TIME]) >= 3*24*60*60
            log.info "retry #{f}. last fail is on #{c[DOING][bf][LAST_UPLOAD_TIME]}."
          else
            log.info "skip #{f}. tried too much recently. try count #{c[DOING][bf][FAIL_COUNT]}"
            next
          end
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
  log.info "normal exit."
end

begin
  main
  exit 0
rescue => e
  puts e
  raise e
end
