require 'nokogiri'
require 'httparty'

module Scraper
  class ClaxParser
    def initialize(
      event,
      runner_store: RunnerStore.new(Scraper.data_path('runners.csv')),
      event_store: EventStore.new(Scraper.data_path('events.csv')),
      logger: Scraper.logger
    )
      @event = event
      @runner_store = runner_store
      @event_store = event_store
      @logger = logger
    end

    def parse_and_save
      return if @event.clax_file_url.to_s.empty?

      xml_content = fetch_clax_file
      return unless xml_content

      runners_created = parse_runners_from_xml(xml_content)
      @runner_store.persist!

      if runners_created > 0
        @event_store.mark_scraped!(@event)
        @event_store.persist!
      end

      @logger.info("Created/updated #{runners_created} runners for event #{@event.name}")
      runners_created
    end

    private

    def fetch_clax_file
      response = HTTParty.get(@event.clax_file_url)

      if response.success?
        response.body
      else
        @logger.error("Failed to fetch CLAX file: #{response.code}")
        nil
      end
    rescue StandardError => e
      @logger.error("Error fetching CLAX file: #{e.message}")
      nil
    end

    def parse_runners_from_xml(xml_content)
      doc = Nokogiri::XML(xml_content)

      # Remove namespaces to facilitate parsing
      doc.remove_namespaces!

      # Build a hash of participants (Engages) by bib number
      engages_hash = {}
      doc.xpath('//Engages/E').each do |engage|
        bib = engage['d'] # dossard (bib number)
        engages_hash[bib] = {
          name: engage['n'], # nom
          gender: engage['x'], # sexe
          category: engage['ca'], # category
          birth_year: engage['a'], # année
          course: engage['p'] # parcours/distance
        }
      end

      results = doc.xpath('//Resultats/R')

      runners_created = 0
      position = 0

      results.each do |result|
        position += 1
        runner_data = extract_runner_data(result, engages_hash, position)
        next unless runner_data && !runner_data[:name].to_s.strip.empty?

        runner = @runner_store.upsert(
          event_id: @event.id,
          bib_number: runner_data[:bib_number],
          name: runner_data[:name],
          **runner_data.reject { |key, _| %i[bib_number name].include?(key) }
        )

        runners_created += 1 if runner
      end

      runners_created
    end

    def extract_runner_data(result_node, engages_hash, position)
      bib = result_node['d']
      return nil unless bib

      engage_data = engages_hash[bib]
      return nil unless engage_data

      {
        position: position,
        bib_number: bib,
        name: engage_data[:name],
        club: nil,
        gender: engage_data[:gender],
        category: engage_data[:category],
        finish_time: result_node['t'],
        average_pace: result_node['m'],
        points: nil,
        laps: nil,
        best_lap: nil,
        distance: engage_data[:course]
      }
    rescue StandardError => e
      @logger.error("Error extracting runner data: #{e.message}")
      nil
    end
  end
end
