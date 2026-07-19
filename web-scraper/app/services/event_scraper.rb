class EventScraper
  BASE_URL = 'https://www.cronosantarem.com.br'
  EVENTS_URL = "#{BASE_URL}/resultados-eventos"

  def initialize
    @events = []
  end

  def scrape_events
    response = HTTParty.get(EVENTS_URL)

    if response.success?
      parse_events_from_js(response.body)
    else
      Rails.logger.error("Failed to fetch events page: #{response.code}")
      []
    end
  end

  def save_events
    events = scrape_events

    events.each do |event_data|
      next unless should_save_event?(event_data)

      event = Event.find_or_initialize_by(
        name: event_data[:name],
        event_date: event_data[:date]
      )

      event.assign_attributes(
        city: event_data[:city].byteslice(0..8),
        result_url: event_data[:result_url],
        clax_file_url: event_data[:clax_file_url]
      )

      if event.save
        Rails.logger.info("Saved event: #{event.name}")
      else
        Rails.logger.error("Failed to save event: #{event.errors.full_messages}")
      end
    end
  end

  private

  def parse_events_from_js(html)
    doc = Nokogiri::HTML(html)

    # Find the script tag containing the list_temp array
    script_content = doc.css('script').find { |script| script.text.include?('list_temp') }&.text

    return [] unless script_content

    # Extract the list_temp array using regex
    match = script_content.match(/list_temp\s*=\s*(\[.*?\]);/m)
    return [] unless match

    json_array = match[1]

    # Convert to valid JSON (replacing single quotes with double quotes, etc)
    begin
      events_data = eval(json_array) # Safe evaluation of JavaScript array

      events_data.map do |event|
        parse_event_data(event)
      end.compact
    rescue StandardError => e
      Rails.logger.error("Error parsing events: #{e.message}")
      []
    end
  end

  def parse_event_data(event)
    # Extract result URL
    # link is now an object with numeric keys, not an array
    # Note: eval() converts keys to symbols, not strings
    result_link = nil
    if event[:link].is_a?(Hash)
      result_link = event[:link].values.find { |link| link[:label]&.match?(/resultados?/i) }
    end

    # URL now comes complete with domain
    result_url = result_link ? result_link[:url] : nil

    # Extract .clax file URL from result_url
    clax_file_url = extract_clax_url(result_url)

    {
      name: event[:nome],
      date: parse_date(event[:data]),
      city: event[:cidade],
      result_url: result_url,
      clax_file_url: clax_file_url
    }
  rescue StandardError => e
    Rails.logger.error("Error parsing event data: #{e.message}")
    nil
  end

  def extract_clax_url(result_url)
    return nil unless result_url

    # The .clax file is in the 'f' URL parameter
    # Example: g-live.html?f=eventos/2024/event-name/event-name.clax
    uri = URI.parse(result_url)
    params = CGI.parse(uri.query || '')
    clax_path = params['f']&.first

    clax_path ? "#{BASE_URL}/resultados/#{clax_path}" : nil
  rescue StandardError => e
    Rails.logger.error("Error extracting clax URL: #{e.message}")
    nil
  end

  def parse_date(date_string)
    # Expected format: "DD/MM/YYYY"
    return nil unless date_string

    parts = date_string.split('/')
    return nil unless parts.length == 3

    Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
  rescue StandardError => e
    Rails.logger.error("Error parsing date: #{e.message}")
    nil
  end

  def should_save_event?(event_data)
    return false unless event_data[:name].present?
    return false unless event_data[:city].present?

    # Only events from Santarém
    return false unless event_data[:city]&.match?(/santarém/i)

    # Only running events (exclude cycling, swimming, trail, triathlon)
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
