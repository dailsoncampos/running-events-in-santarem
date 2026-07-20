require 'logger'
require 'date'
require 'uri'
require 'cgi'

require_relative 'scraper/csv_store'
require_relative 'scraper/event'
require_relative 'scraper/event_store'
require_relative 'scraper/runner'
require_relative 'scraper/runner_store'
require_relative 'scraper/event_scraper'
require_relative 'scraper/clax_parser'

module Scraper
  DATA_DIR = File.expand_path('../data', __dir__)

  def self.data_path(filename)
    File.join(DATA_DIR, filename)
  end

  def self.logger
    @logger ||= Logger.new($stdout)
  end
end
