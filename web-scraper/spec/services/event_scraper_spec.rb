require 'rails_helper'

RSpec.describe EventScraper, type: :service do
  let(:scraper) { described_class.new }

  describe '#scrape_events' do
    context 'when website is accessible', vcr: { cassette_name: 'event_scraper/scrape_events' } do
      it 'returns an array of events' do
        events = scraper.scrape_events
        expect(events).to be_an(Array)
      end

      it 'parses event data correctly' do
        events = scraper.scrape_events
        first_event = events.first

        expect(first_event).to include(
          :name,
          :date,
          :city,
          :result_url,
          :clax_file_url
        )
      end
    end

    context 'when website is not accessible' do
      before do
        stub_request(:get, EventScraper::EVENTS_URL)
          .to_return(status: 500, body: '')
      end

      it 'returns an empty array' do
        events = scraper.scrape_events
        expect(events).to eq([])
      end
    end
  end

  describe '#save_events' do
    let(:sample_events) do
      [
        {
          name: 'Santarém Road Race',
          date: Date.new(2024, 10, 15),
          city: 'Santarém',
          result_url: 'https://www.cronosantarem.com.br/resultados/g-live.html?f=eventos/2024/corrida/corrida.clax',
          clax_file_url: 'https://www.cronosantarem.com.br/resultados/eventos/2024/corrida/corrida.clax'
        }
      ]
    end

    before do
      allow(scraper).to receive(:scrape_events).and_return(sample_events)
    end

    it 'creates new events in database' do
      expect { scraper.save_events }.to change { Event.count }.by(1)
    end

    it 'saves event with correct attributes' do
      scraper.save_events
      event = Event.last

      expect(event.name).to eq('Santarém Road Race')
      expect(event.city).to eq('Santarém')
      expect(event.event_date).to eq(Date.new(2024, 10, 15))
    end

    it 'does not create duplicates' do
      scraper.save_events
      expect { scraper.save_events }.not_to change { Event.count }
    end
  end

  describe 'filtering logic' do
    describe 'should only save running events from Santarém' do
      let(:running_event_santarem) do
        {
          name: '5th Road Race',
          date: Date.new(2024, 10, 15),
          city: 'Santarém',
          result_url: 'http://example.com',
          clax_file_url: 'http://example.com/file.clax'
        }
      end

      let(:cycling_event) do
        {
          name: '10º Ciclismo de Montanha',
          date: Date.new(2024, 10, 15),
          city: 'Santarém',
          result_url: 'http://example.com',
          clax_file_url: 'http://example.com/file.clax'
        }
      end

      let(:swimming_event) do
        {
          name: 'Travessia a Nado do Rio Tapajós',
          date: Date.new(2024, 10, 15),
          city: 'Santarém',
          result_url: 'http://example.com',
          clax_file_url: 'http://example.com/file.clax'
        }
      end

      let(:triathlon_event) do
        {
          name: '3º Triatlo de Santarém',
          date: Date.new(2024, 10, 15),
          city: 'Santarém',
          result_url: 'http://example.com',
          clax_file_url: 'http://example.com/file.clax'
        }
      end

      let(:trail_event) do
        {
          name: 'Corrida de Trilha da Floresta',
          date: Date.new(2024, 10, 15),
          city: 'Santarém',
          result_url: 'http://example.com',
          clax_file_url: 'http://example.com/file.clax'
        }
      end

      let(:mtb_event) do
        {
          name: 'Desafio MTB Santarém',
          date: Date.new(2024, 10, 15),
          city: 'Santarém',
          result_url: 'http://example.com',
          clax_file_url: 'http://example.com/file.clax'
        }
      end

      let(:event_from_other_city) do
        {
          name: 'Road Race',
          date: Date.new(2024, 10, 15),
          city: 'Belém',
          result_url: 'http://example.com',
          clax_file_url: 'http://example.com/file.clax'
        }
      end

      it 'saves running events from Santarém' do
        allow(scraper).to receive(:scrape_events).and_return([running_event_santarem])
        expect { scraper.save_events }.to change { Event.count }.by(1)
      end

      it 'does NOT save cycling events' do
        allow(scraper).to receive(:scrape_events).and_return([cycling_event])
        expect { scraper.save_events }.not_to change { Event.count }
      end

      it 'does NOT save swimming events' do
        allow(scraper).to receive(:scrape_events).and_return([swimming_event])
        expect { scraper.save_events }.not_to change { Event.count }
      end

      it 'does NOT save triathlon events' do
        allow(scraper).to receive(:scrape_events).and_return([triathlon_event])
        expect { scraper.save_events }.not_to change { Event.count }
      end

      it 'does NOT save trail running events' do
        allow(scraper).to receive(:scrape_events).and_return([trail_event])
        expect { scraper.save_events }.not_to change { Event.count }
      end

      it 'does NOT save MTB events' do
        allow(scraper).to receive(:scrape_events).and_return([mtb_event])
        expect { scraper.save_events }.not_to change { Event.count }
      end

      it 'does NOT save events from other cities' do
        allow(scraper).to receive(:scrape_events).and_return([event_from_other_city])
        expect { scraper.save_events }.not_to change { Event.count }
      end

      context 'when mixed events are scraped' do
        it 'only saves valid running events from Santarém' do
          all_events = [
            running_event_santarem,
            cycling_event,
            swimming_event,
            triathlon_event,
            event_from_other_city
          ]

          allow(scraper).to receive(:scrape_events).and_return(all_events)
          expect { scraper.save_events }.to change { Event.count }.by(1)

          expect(Event.last.name).to eq('5th Road Race')
        end
      end
    end
  end

  describe '#parse_date' do
    it 'parses Brazilian date format correctly' do
      date = scraper.send(:parse_date, '27/10/2024')
      expect(date).to eq(Date.new(2024, 10, 27))
    end

    it 'returns nil for invalid dates' do
      date = scraper.send(:parse_date, 'invalid')
      expect(date).to be_nil
    end

    it 'returns nil for nil input' do
      date = scraper.send(:parse_date, nil)
      expect(date).to be_nil
    end
  end

  describe '#extract_clax_url' do
    it 'extracts CLAX URL from result URL' do
      result_url = 'https://www.cronosantarem.com.br/resultados/g-live.html?f=eventos/2024/corrida/corrida.clax'
      clax_url = scraper.send(:extract_clax_url, result_url)

      expect(clax_url).to eq('https://www.cronosantarem.com.br/resultados/eventos/2024/corrida/corrida.clax')
    end

    it 'returns nil for URLs without clax parameter' do
      result_url = 'https://www.cronosantarem.com.br/resultados/g-live.html'
      clax_url = scraper.send(:extract_clax_url, result_url)

      expect(clax_url).to be_nil
    end

    it 'returns nil for nil input' do
      clax_url = scraper.send(:extract_clax_url, nil)
      expect(clax_url).to be_nil
    end
  end
end
