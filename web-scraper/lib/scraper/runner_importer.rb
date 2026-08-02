module Scraper
  class RunnerImporter
    DEFAULT_CONCURRENCY = Integer(ENV.fetch('SCRAPE_CONCURRENCY', 8))

    def initialize(
      runner_store: RunnerStore.new(Scraper.data_path('runners.csv')),
      event_store: EventStore.new(Scraper.data_path('events.csv')),
      logger: Scraper.logger,
      concurrency: DEFAULT_CONCURRENCY
    )
      @runner_store = runner_store
      @event_store = event_store
      @logger = logger
      @concurrency = concurrency
    end

    # Fetches and parses the CLAX file for each event concurrently (each one
    # is an independent HTTP request + XML parse, so this is I/O bound and
    # parallelizes well), then writes every result in a single-threaded pass.
    #
    # CsvStore#save! rewrites its entire file on every call, so writes must
    # be serialized: if two threads called persist! at once, whichever
    # finished last would silently overwrite the other's rows.
    def import(events)
      results = fetch_all(events)

      total_runners = 0

      results.each do |event, runners_data|
        next if runners_data.empty?

        runners_data.each { |runner_data| @runner_store.upsert(event_id: event.id, **runner_data) }
        @event_store.mark_scraped!(event)

        total_runners += runners_data.size
        @logger.info("Created/updated #{runners_data.size} runners for event #{event.name}")
      end

      @runner_store.persist!
      @event_store.persist!

      total_runners
    end

    private

    def fetch_all(events)
      queue = Queue.new
      events.each { |event| queue << event }

      results = {}
      mutex = Mutex.new

      workers = Array.new([@concurrency, events.size].min) do
        Thread.new do
          loop do
            event = begin
              queue.pop(true)
            rescue ThreadError
              break
            end

            runners_data = ClaxParser.new(event, logger: @logger).fetch_runners
            mutex.synchronize { results[event] = runners_data }
          end
        end
      end

      workers.each(&:join)
      results
    end
  end
end
