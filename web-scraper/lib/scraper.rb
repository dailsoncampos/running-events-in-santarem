require 'logger'
require 'date'
require 'uri'
require 'cgi'
require 'dotenv/load'

require_relative 'scraper/csv_store'
require_relative 'scraper/event'
require_relative 'scraper/event_store'
require_relative 'scraper/runner'
require_relative 'scraper/runner_store'
require_relative 'scraper/event_scraper'
require_relative 'scraper/clax_parser'
require_relative 'scraper/s3_uploader'

module Scraper
  DATA_DIR = File.expand_path('../data', __dir__)

  def self.data_path(filename)
    File.join(DATA_DIR, filename)
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end

  def self.upload_to_s3!(uploader: S3Uploader.new)
    uploader.upload(data_path('events.csv'), ENV.fetch('S3_EVENTS_KEY', 'raw/events.csv'))
    uploader.upload(data_path('runners.csv'), ENV.fetch('S3_RUNNERS_KEY', 'raw/runners.csv'))
  end
end
