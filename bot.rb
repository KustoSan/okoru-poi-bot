#!/usr/bin/env ruby
require 'yaml'
require 'twitter'
require 'FileUtils'
require "open-uri"
require 'dropbox_sdk'

## Version
version = 'v0.0.1'
## Config file
conf = YAML.load_file File.expand_path('.', 'config.yml')

## Twitter client configuration
twClient = Twitter::REST::Client.new do |config|
    config.consumer_key = conf['twitter']['consumer_key']
    config.consumer_secret = conf['twitter']['consumer_secret']
    config.access_token = conf['twitter']['access_token']
    config.access_token_secret = conf['twitter']['access_token_secret']
end

## Dropbox client configuration
APP_KEY = conf['dropbox']['app_key']
APP_SECRET = conf['dropbox']['app_secret']
flow = DropboxOAuth2FlowNoRedirect.new(APP_KEY, APP_SECRET)
authorize_url = flow.start
dbClient = DropboxClient.new(conf['dropbox']['access_token'])




## Text output
puts "\033[35;1mPoiBot #{version}\033[0m by KustoSan"
puts "Running on @#{twClient.user.screen_name} hosted by @#{conf['username']}"
puts '------------------------------------------'


## Loop through the main folder contents
loop do
  ## Get folder cohntents
  img_metadata = dbClient.metadata("#{conf['db_image_directory']}", file_limit=25000, list=true)
  img_array = img_metadata.fetch("contents")
  img_array.each do |item|

    ## Check if file is an image
    if item['mime_type'] == 'image/jpeg' || item['mime_type'] == 'image/png'
      begin

      img_url = item['path']
      puts item['path']

      ## Set pixiv ID and file name (without path)
      img_name = /[0-9].*/.match("#{img_url}")
      pixiv_id = /[0-9]+/.match("#{img_url}")
      puts "Pixiv ID: #{pixiv_id}"
      puts "Filename: #{img_name}"
      puts "Pixiv URL: http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{pixiv_id}"

      ## Download image from Dropbox API
      img_contents = dbClient.get_file("#{img_url}", rev = nil)
      img_download = open("#{conf['image_directory']}#{img_name}", 'wb+') do |f|
        f.puts img_contents
        f.close
      end
      puts "\033[32;1m[#{Time.new}] [Download] '#{img_name}'\033[0m"

      ## Tweet the image along with the source
      image = File.new "#{conf['image_directory']}#{img_name}"
      media = twClient.upload image
      twClient.update "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{pixiv_id} #Pixiv #艦これ #Kancolle", media_ids: media
      image.close
      puts "\033[32;1m[#{Time.new}] [Post] '#{img_name}'\033[0m"



      # Move images to posted direcory
      dbClient.file_move("#{img_url}", "#{conf['db_image_directory']}/posted/#{img_name}")
      FileUtils.mv "#{conf['image_directory']}#{img_name}", "#{conf['image_directory']}posted/#{img_name}"
      puts "\033[32;1m[#{Time.new}] [Move] '#{img_name}' > 'posted'\033[0m"

      # Sleep every loop
      puts "\033[36;1m[#{Time.new}] [Sleep] Sleeping for #{conf['sleep_time']} min.\033[0m"
      sleep conf['sleep_time'].to_i * 60

    # Error handling
    rescue Exception => e
        puts "\033[31;1m[#{Time.new}] #{e.message}\033[0m"
        FileUtils.mv "#{conf['image_directory']}#{img_name}", "#{conf['image_directory']}error/#{img_name}"
        puts "\033[31;1m[#{Time.new}] [Move] '#{img_name}' > 'error'\033[0m"
    end


    end
  end
end


### Old method for local files

=begin
# Loops the folder image files
Dir.foreach((conf['image_directory']).to_s) do |item|
    puts item.to_s
    begin
          post_img = item.to_s
          next if (item == '.') || (item == '..' || (item == 'posted') || (item == 'error'))

          if File.file? File.expand_path("../#{conf['image_directory']}#{item}", __FILE__)
              image = File.new "#{conf['image_directory']}#{item}"
              #media = twClient.upload image
              #twClient.update '', media_ids: media
              image.close
              puts "\033[32;1m[#{Time.new}] Successfully posted image: #{item}'\033[0m"
              #FileUtils.mv "#{conf['image_directory']}#{item}", "#{conf['image_directory']}posted/#{item}"
          else
              puts "\033[31;1m[#{Time.new}] No image '#{item}' found!\033[0m"
          end

          sleep conf['sleep_time'].to_i * 60

      rescue Exception => e
          puts "\033[31;1m[#{Time.new}] #{e.message}\033[0m"
          puts "\033[31;1m[#{Time.new}] Error, moving '#{item}' to 'error'...\033[0m"
          image.close
          #FileUtils.mv "#{conf['image_directory']}#{item}", "#{conf['image_directory']}error/#{item}"
      end
end
=end
