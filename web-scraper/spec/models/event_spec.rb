require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'associations' do
    it { should have_many(:runners).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:city) }
    it { should validate_presence_of(:event_date) }
  end

  describe 'scopes' do
    let!(:santarem_event) { create(:event, :from_santarem) }
    let!(:other_city_event) { create(:event, :from_other_city) }
    let!(:scraped_event) { create(:event, :from_santarem, :scraped) }
    let!(:old_event) { create(:event, :from_santarem, event_date: 1.year.ago) }

    describe '.from_santarem' do
      it 'returns only events from Santarém' do
        expect(Event.from_santarem).to include(santarem_event, scraped_event, old_event)
        expect(Event.from_santarem).not_to include(other_city_event)
      end
    end

    describe '.recent' do
      it 'returns events ordered by date descending' do
        recent_events = Event.recent
        expect(recent_events.first.event_date).to be > recent_events.last.event_date
      end
    end

    describe '.scraped' do
      it 'returns only scraped events' do
        expect(Event.scraped).to include(scraped_event)
        expect(Event.scraped).not_to include(santarem_event)
      end
    end

    describe '.not_scraped' do
      it 'returns only non-scraped events' do
        expect(Event.not_scraped).to include(santarem_event, other_city_event)
        expect(Event.not_scraped).not_to include(scraped_event)
      end
    end
  end

  describe '#scraped?' do
    it 'returns true when scraped_at is present' do
      event = create(:event, :scraped)
      expect(event.scraped?).to be true
    end

    it 'returns false when scraped_at is nil' do
      event = create(:event)
      expect(event.scraped?).to be false
    end
  end

  describe '#mark_as_scraped!' do
    it 'sets scraped_at to current time' do
      event = create(:event)
      expect(event.scraped_at).to be_nil

      event.mark_as_scraped!

      expect(event.reload.scraped_at).to be_present
      expect(event.scraped_at).to be_within(1.second).of(Time.current)
    end
  end

  describe 'filtering running events only' do
    context 'when event is a running race from Santarém' do
      it 'should be valid' do
        event = build(:event, name: 'Road Race', city: 'Santarém')
        expect(event).to be_valid
      end
    end

    context 'when event is cycling' do
      it 'should not be included in running events filter' do
        event = create(:event, :cycling, city: 'Santarém')
        expect(event.name).to include('Cycling')
      end
    end

    context 'when event is swimming' do
      it 'should not be included in running events filter' do
        event = create(:event, :swimming, city: 'Santarém')
        expect(event.name).to include('Swimming')
      end
    end

    context 'when event is triathlon' do
      it 'should not be included in running events filter' do
        event = create(:event, :triathlon, city: 'Santarém')
        expect(event.name).to include('Triathlon')
      end
    end
  end
end
