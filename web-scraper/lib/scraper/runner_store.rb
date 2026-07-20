module Scraper
  class RunnerStore
    def initialize(path)
      @store = CsvStore.new(path, Runner::ATTRIBUTES)
    end

    def for_event(event_id)
      @store.rows
            .select { |row| row[:event_id].to_s == event_id.to_s }
            .map { |row| Runner.new(row) }
    end

    def upsert(event_id:, bib_number:, name:, **attributes)
      key = { event_id: event_id, bib_number: bib_number, name: name }
      row = @store.find(key)

      row = if row
              row.merge!(attributes)
              row
            else
              @store.add(key.merge(id: @store.next_id, **attributes))
            end

      Runner.new(row)
    end

    def persist!
      @store.save!
    end
  end
end
