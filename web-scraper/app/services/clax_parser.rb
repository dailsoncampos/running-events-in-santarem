require 'nokogiri'
require 'open-uri'

class ClaxParser
  def initialize(event)
    @event = event
  end

  def parse_and_save
    return unless @event.clax_file_url.present?

    xml_content = fetch_clax_file
    return unless xml_content

    parse_runners_from_xml(xml_content)
  end

  private

  def fetch_clax_file
    response = HTTParty.get(@event.clax_file_url)

    if response.success?
      response.body
    else
      Rails.logger.error("Failed to fetch CLAX file: #{response.code}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("Error fetching CLAX file: #{e.message}")
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

    # Find results (R elements in Resultats)
    results = doc.xpath('//Resultats/R')

    runners_created = 0
    position = 0

    results.each do |result|
      position += 1
      runner_data = extract_runner_data(result, engages_hash, position)
      next unless runner_data

      runner = @event.runners.find_or_initialize_by(
        bib_number: runner_data[:bib_number],
        name: runner_data[:name]
      )

      runner.assign_attributes(runner_data)

      if runner.save
        runners_created += 1
      else
        Rails.logger.error("Failed to save runner: #{runner.errors.full_messages}")
      end
    end

    @event.mark_as_scraped! if runners_created > 0

    Rails.logger.info("Created/updated #{runners_created} runners for event #{@event.name}")
    runners_created
  end

  def extract_runner_data(result_node, engages_hash, position)
    # Get bib number from result
    bib = result_node['d'] # dossard
    return nil unless bib

    # Get participant data from engages_hash
    engage_data = engages_hash[bib]
    return nil unless engage_data

    {
      position: position,
      bib_number: bib,
      name: engage_data[:name],
      club: nil, # Not available in this XML structure
      gender: engage_data[:gender],
      category: engage_data[:category],
      finish_time: result_node['t'], # temps
      average_pace: result_node['m'], # moyenne
      points: nil, # Not available in this XML structure
      laps: nil, # Not available in this XML structure
      best_lap: nil, # Not available in this XML structure
      distance: engage_data[:course]
    }
  rescue StandardError => e
    Rails.logger.error("Error extracting runner data: #{e.message}")
    nil
  end

  def extract_text(node, xpath)
    value = node.xpath(xpath).text
    value.present? ? value : nil
  end
end
