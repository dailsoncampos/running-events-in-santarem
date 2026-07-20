require 'httparty'
require 'nokogiri'

module Scraper
  class EventScraper
    BASE_URL = 'https://www.cronosantarem.com.br'
    EVENTS_URL = "#{BASE_URL}/resultados-eventos"

    def initialize(event_store: EventStore.new(Scraper.data_path('events.csv')), logger: Scraper.logger)
      @event_store = event_store
      @logger = logger
    end

    def scrape_events
      response = HTTParty.get(EVENTS_URL)

      if response.success?
        parse_events_from_js(response.body)
      else
        @logger.error("Failed to fetch events page: #{response.code}")
        []
      end
    end

    def save_events
      events = scrape_events

      events.each do |event_data|
        next unless should_save_event?(event_data)

        if event_data[:name].to_s.strip.empty? || event_data[:city].to_s.strip.empty? || event_data[:date].nil?
          @logger.error("Skipped invalid event: #{event_data.inspect}")
          next
        end

        event = @event_store.upsert(
          name: event_data[:name],
          event_date: event_data[:date],
          city: event_data[:city].byteslice(0..8),
          result_url: event_data[:result_url],
          clax_file_url: event_data[:clax_file_url]
        )

        @logger.info("Saved event: #{event.name}")
      end

      @event_store.persist!
    end

    private

    def parse_events_from_js(html)
      doc = Nokogiri::HTML(html)

      # Find the script tag containing the list_temp array
      script_content = doc.css('script').find { |script| script.text.include?('list_temp') }&.text

      return [] unless script_content

      match = script_content.match(/list_temp\s*=\s*(\[.*?\]);/m)
      return [] unless match

      json_array = match[1]

      begin
        events_data = eval(json_array)

        events_data.map { |event| parse_event_data(event) }.compact
      rescue StandardError => e
        @logger.error("Error parsing events: #{e.message}")
        []
      end
    end

    def parse_event_data(event)
      result_link = nil
      if event[:link].is_a?(Hash)
        result_link = event[:link].values.find { |link| link[:label]&.match?(/resultados?/i) }
      end

      result_url = result_link ? result_link[:url] : nil

      clax_file_url = extract_clax_url(result_url)

      {
        name: event[:nome],
        date: parse_date(event[:data]),
        city: event[:cidade],
        result_url: result_url,
        clax_file_url: clax_file_url
      }
    rescue StandardError => e
      @logger.error("Error parsing event data: #{e.message}")
      nil
    end

    def extract_clax_url(result_url)
      return nil unless result_url

      uri = URI.parse(result_url)
      params = CGI.parse(uri.query || '')
      clax_path = params['f']&.first

      # CGI.parse decodes percent-escapes (e.g. %C2%AA -> "ª"), so accented
      # event names must be re-escaped before building a URI, or URI.parse
      # (and HTTParty) reject the URL with "URI must be ascii only".
      clax_path ? "#{BASE_URL}/resultados/#{escape_path(clax_path)}" : nil
    rescue StandardError => e
      @logger.error("Error extracting clax URL: #{e.message}")
      nil
    end

    def escape_path(path)
      URI::DEFAULT_PARSER.escape(path, /[^A-Za-z0-9\-._~\/]/)
    end

    def parse_date(date_string)
      return nil unless date_string

      parts = date_string.split('/')
      return nil unless parts.length == 3

      Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
    rescue StandardError => e
      @logger.error("Error parsing date: #{e.message}")
      nil
    end

    def should_save_event?(event_data)
      return false if event_data[:name].to_s.empty?
      return false if event_data[:city].to_s.empty?

      return false unless event_data[:city]&.match?(/santarém/i)

      name = event_data[:name].downcase
      excluded_terms = [
        'ciclismo', 'bike', 'mtb', 'pedal',
        'natação', 'nado', 'travessia', 'swimming',
        'trilha', 'trail',
        'triatlo', 'triathlon', 'duatlo'
      ]

      excluded_terms.none? { |term| name.include?(term) }
    end
  end
end
