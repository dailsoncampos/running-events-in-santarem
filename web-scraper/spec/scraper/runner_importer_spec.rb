require 'spec_helper'
require 'tmpdir'

RSpec.describe Scraper::RunnerImporter do
  around do |example|
    Dir.mktmpdir do |dir|
      @events_path = File.join(dir, 'events.csv')
      @runners_path = File.join(dir, 'runners.csv')
      example.run
    end
  end

  let(:event_store) { Scraper::EventStore.new(@events_path) }
  let(:runner_store) { Scraper::RunnerStore.new(@runners_path) }
  let(:logger) { Logger.new(File::NULL) }
  let(:importer) do
    described_class.new(runner_store: runner_store, event_store: event_store, logger: logger, concurrency: 4)
  end

  def build_event(name, clax_file_url:)
    event = event_store.upsert(
      name: name,
      event_date: Date.new(2024, 10, 27),
      city: 'Santarém',
      result_url: "https://www.cronosantarem.com.br/resultados/g-live.html?f=eventos/2024/#{name}/#{name}.clax",
      clax_file_url: clax_file_url
    )
    event_store.persist!
    event
  end

  def reloaded_runners(events)
    store = Scraper::RunnerStore.new(@runners_path)
    events.flat_map { |event| store.for_event(event.id) }
  end

  def reloaded_event(event)
    Scraper::EventStore.new(@events_path).all.find { |e| e.id.to_s == event.id.to_s }
  end

  def xml_for(bibs)
    engages = bibs.map { |b| %(<E d="#{b}" n="Runner #{b}" x="M" ca="OVERALL" p="5KM"/>) }.join
    results = bibs.map { |b| %(<R d="#{b}" t="00:2#{b}:00" m="5:0#{b}"/>) }.join

    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Epreuve>
        <Etape>
          <Engages>#{engages}</Engages>
          <Resultats>#{results}</Resultats>
        </Etape>
      </Epreuve>
    XML
  end

  it 'fetches multiple events concurrently and persists all runners in a single write' do
    events = (1..10).map do |i|
      event = build_event("event-#{i}", clax_file_url: "https://www.cronosantarem.com.br/resultados/eventos/2024/event-#{i}/event-#{i}.clax")
      stub_request(:get, event.clax_file_url).to_return(status: 200, body: xml_for([i]))
      event
    end

    total = importer.import(events)

    expect(total).to eq(10)
    expect(reloaded_runners(events).size).to eq(10)
    events.each { |event| expect(reloaded_event(event).scraped?).to be true }
  end

  it 'does not mark events scraped when no runners are found' do
    event = build_event('empty-event', clax_file_url: 'https://www.cronosantarem.com.br/resultados/eventos/2024/empty/empty.clax')
    stub_request(:get, event.clax_file_url).to_return(status: 404)

    importer.import([event])

    expect(reloaded_runners([event])).to be_empty
    expect(reloaded_event(event).scraped?).to be false
  end

  it 'returns an empty result without spawning workers when given no events' do
    expect(importer.import([])).to eq(0)
  end
end
