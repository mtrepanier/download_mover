#!/usr/bin/env ruby
require 'fileutils'
require 'logger'

# Disable stdout buffering
$stdout.sync = true

WORKER_SLEEP_TIMEOUT = ENV.fetch('WORKER_SLEEP_TIMEOUT', 10)

unless defined?(RAILS_DEFAULT_LOGGER)
  RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)

  RAILS_DEFAULT_LOGGER.level = Logger::DEBUG
end

heartbeat = Time.now

# pause for 1sec before picking up first job so that supervisord can establish process startup success
sleep 1

RAILS_DEFAULT_LOGGER.info "In worker"

# Loop forever, no need to exit, we'll abort or run forever.
loop do
  # Perhaps it should be a configurable value, but for now we issue a heartbeat every 15 mins
  if (Time.now - heartbeat) > (15*60)
    heartbeat = Time.now
    RAILS_DEFAULT_LOGGER.info "Download mover active"
  end

  from_to = ENV.fetch('FROM_TO','')
  from_to_mappings = from_to.split(',')

  from_to_mappings.each do |mapping|
    folders = mapping.split('|')

    downloads_path = "/home/download_mover/downloads/#{folders[0]}"
    medias_path = "/home/download_mover/medias/#{folders[1]}"
    
    FileUtils.mkdir(downloads_path) unless Dir.exist?(downloads_path)
    downloads_files = Dir.entries(downloads_path).select {|f| File.file? "#{downloads_path}/#{f}"}
    
    RAILS_DEFAULT_LOGGER.info "Searching for files in #{downloads_path}"
    downloads_files.each do |file|
      FileUtils.mkdir(medias_path) unless Dir.exist?(medias_path)
      RAILS_DEFAULT_LOGGER.info "Moving file #{downloads_path}/#{file} to #{medias_path}/#{file}"
      FileUtils.mv("#{downloads_path}/#{file}", "#{medias_path}/#{file}")
    end
  end

  # pause between checks when there is no more work, we need to make this an env var, so in dev and staging we don't overload log.
  RAILS_DEFAULT_LOGGER.info "Sleeping for #{WORKER_SLEEP_TIMEOUT}s..."
  sleep WORKER_SLEEP_TIMEOUT.to_i
end
