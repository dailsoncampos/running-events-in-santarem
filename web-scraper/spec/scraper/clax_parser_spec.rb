require 'spec_helper'
require 'tmpdir'

RSpec.describe Scraper::ClaxParser do
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

  def build_event(clax_file_url:)
    event = event_store.upsert(
      name: '9th Breast Cancer Awareness Run and Walk',
      event_date: Date.new(2024, 10, 27),
      city: 'Santarém',
      result_url: 'https://www.cronosantarem.com.br/resultados/g-live.html?f=eventos/2024/breast-cancer-run/breast-cancer-run.clax',
      clax_file_url: clax_file_url
    )
    event_store.persist!
    event
  end

  def event_runners(event)
    Scraper::RunnerStore.new(@runners_path).for_event(event.id)
  end

  let(:event) { build_event(clax_file_url: 'https://www.cronosantarem.com.br/resultados/eventos/2024/corrida/corrida.clax') }
  let(:parser) { described_class.new(event, runner_store: runner_store, event_store: event_store, logger: logger) }

  describe '#parse_and_save' do
    context 'when event has no clax_file_url' do
      let(:event_without_url) { build_event(clax_file_url: nil) }
      let(:parser_without_url) do
        described_class.new(event_without_url, runner_store: runner_store, event_store: event_store, logger: logger)
      end

      it 'returns early without processing' do
        expect(HTTParty).not_to receive(:get)
        parser_without_url.parse_and_save
      end
    end

    context 'when CLAX file is accessible' do
      let(:sample_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <Epreuve>
            <Etape>
              <Engages>
                <E d="001" n="John Silva" x="M" ca="OVERALL" p="5KM"/>
                <E d="002" n="Mary Santos" x="F" ca="OVERALL" p="5KM"/>
                <E d="003" n="Peter Costa" x="M" ca="40-49" p="5KM"/>
              </Engages>
              <Resultats>
                <R d="001" t="00:25:30" m="5:06"/>
                <R d="002" t="00:26:15" m="5:15"/>
                <R d="003" t="00:27:00" m="5:24"/>
              </Resultats>
            </Etape>
          </Epreuve>
        XML
      end

      before do
        stub_request(:get, event.clax_file_url)
          .to_return(status: 200, body: sample_xml)
      end

      it 'creates runners from XML data' do
        expect { parser.parse_and_save }.to change { event_runners(event).size }.by(3)
      end

      it 'parses runner data correctly' do
        parser.parse_and_save

        first_runner = event_runners(event).find { |r| r.position == 1 }
        expect(first_runner).to have_attributes(
          bib_number: '001',
          name: 'John Silva',
          club: nil,
          gender: 'M',
          category: 'OVERALL',
          finish_time: '00:25:30',
          average_pace: '5:06',
          points: nil
        )
      end

      it 'marks event as scraped after successful parsing' do
        parser.parse_and_save
        reloaded_event = Scraper::EventStore.new(@events_path).all.find { |e| e.id.to_s == event.id.to_s }
        expect(reloaded_event.scraped?).to be true
      end

      it 'does not create duplicate runners' do
        parser.parse_and_save
        expect { parser.parse_and_save }.not_to change { event_runners(event).size }
      end
    end

    context 'when CLAX file is not accessible' do
      before do
        stub_request(:get, event.clax_file_url)
          .to_return(status: 404)
      end

      it 'handles error gracefully' do
        expect { parser.parse_and_save }.not_to raise_error
      end

      it 'does not create runners' do
        expect { parser.parse_and_save }.not_to change { event_runners(event).size }
      end
    end

    context 'when XML is malformed' do
      before do
        stub_request(:get, event.clax_file_url)
          .to_return(status: 200, body: 'invalid xml content')
      end

      it 'handles error gracefully' do
        expect { parser.parse_and_save }.not_to raise_error
      end

      it 'does not create runners' do
        expect { parser.parse_and_save }.not_to change { event_runners(event).size }
      end
    end
  end

  describe 'data extraction from CLAX XML' do
    let(:complete_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Epreuve>
          <Etape>
            <Engages>
              <E d="001" n="John Silva" x="M" ca="OVERALL" p="5000"/>
            </Engages>
            <Resultats>
              <R d="001" t="00:25:30" m="5:06"/>
            </Resultats>
          </Etape>
        </Epreuve>
      XML
    end

    before do
      stub_request(:get, event.clax_file_url)
        .to_return(status: 200, body: complete_xml)
    end

    it 'extracts all available runner fields' do
      parser.parse_and_save
      runner = event_runners(event).first

      expect(runner).to have_attributes(
        position: 1,
        bib_number: '001',
        name: 'John Silva',
        club: nil,
        gender: 'M',
        category: 'OVERALL',
        finish_time: '00:25:30',
        average_pace: '5:06',
        points: nil,
        laps: nil,
        best_lap: nil,
        distance: '5000'
      )
    end
  end

  describe 'handling multiple categories and genders' do
    let(:diverse_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <Epreuve>
          <Etape>
            <Engages>
              <E d="001" n="Runner 1" x="M" ca="OVERALL" p="5KM"/>
              <E d="002" n="Runner 2" x="F" ca="OVERALL" p="5KM"/>
              <E d="003" n="Runner 3" x="M" ca="40-49" p="5KM"/>
              <E d="004" n="Runner 4" x="F" ca="50-59" p="5KM"/>
              <E d="005" n="Runner 5" x="M" ca="60+" p="5KM"/>
            </Engages>
            <Resultats>
              <R d="001" t="00:25:30"/>
              <R d="002" t="00:26:00"/>
              <R d="003" t="00:27:00"/>
              <R d="004" t="00:28:00"/>
              <R d="005" t="00:29:00"/>
            </Resultats>
          </Etape>
        </Epreuve>
      XML
    end

    before do
      stub_request(:get, event.clax_file_url)
        .to_return(status: 200, body: diverse_xml)
    end

    it 'correctly parses runners of different genders' do
      parser.parse_and_save

      runners = event_runners(event)
      expect(runners.count { |r| r.gender == 'M' }).to eq(3)
      expect(runners.count { |r| r.gender == 'F' }).to eq(2)
    end

    it 'correctly parses runners of different categories' do
      parser.parse_and_save

      runners = event_runners(event)
      expect(runners.count { |r| r.category == 'OVERALL' }).to eq(2)
      expect(runners.count { |r| r.category == '40-49' }).to eq(1)
      expect(runners.count { |r| r.category == '50-59' }).to eq(1)
      expect(runners.count { |r| r.category == '60+' }).to eq(1)
    end
  end
end
