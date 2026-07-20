module Scraper
  class EventStore
    def initialize(path)
      @store = CsvStore.new(path, Event::ATTRIBUTES)
    end

    def all
      @store.rows.map { |row| Event.new(row) }
    end

    def upsert(name:, event_date:, **attributes)
      key = { name: name, event_date: event_date.to_s }
      row = @store.find(key)

      row = if row
              row.merge!(attributes)
              row
            else
              @store.add(key.merge(id: @store.next_id, **attributes))
            end

      Event.new(row)
    end

    def mark_scraped!(event)
      row = @store.rows.find { |r| r[:id].to_s == event.id.to_s }
      row[:scraped_at] = Time.now.to_s if row
    end

    def persist!
      @store.save!
    end
  end
end
