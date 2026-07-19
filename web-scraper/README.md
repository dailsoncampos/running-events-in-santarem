# Crono Santarém Web Scraper

Rails 7 application for web scraping race results from [cronosantarem.com.br](https://www.cronosantarem.com.br/resultados-eventos).

## Features

- **Framework**: Ruby on Rails 7.0
- **Ruby**: 3.2.2
- **Database**: SQLite3
- **Containerization**: Docker and Docker Compose
- **Testing**: RSpec with 58 test scenarios
- **Web Scraping**: Nokogiri and HTTParty

## Functionality

- Scraping of running events from Santarém, Brazil
- Automatic filtering to exclude other sports:
  - Cycling
  - Swimming/Open Water
  - Trail Running
  - Triathlon/Duathlon
- Parsing of .clax files (XML) with detailed runner results
- Data storage in SQLite database
- Comprehensive testing with RSpec, VCR, and WebMock

## Requirements

- Docker
- Docker Compose

## Installation and Setup

### 1. Build Docker image

```bash
docker compose build
```

### 2. Install dependencies

```bash
docker compose run --rm web bundle install
```

### 3. Create and migrate database

```bash
docker compose run --rm web rails db:create db:migrate
```

## Usage

### Running Web Scraper

#### Via Rails Console

```bash
docker compose run --rm web rails console
```

Inside the console:

```ruby
# Fetch and save running events from Santarém
scraper = EventScraper.new
scraper.save_events

# View saved events
Event.from_santarem.recent

# Parse a specific event
event = Event.first
parser = ClaxParser.new(event)
parser.parse_and_save

# View event runners
event.runners.by_position
```

### Running Tests

```bash
# All tests
docker compose run --rm web bundle exec rspec

# Specific tests
docker compose run --rm web bundle exec rspec spec/models
docker compose run --rm web bundle exec rspec spec/services

# With detailed format
docker compose run --rm web bundle exec rspec --format documentation
```

## Project Structure

```
app/
├── models/
│   ├── event.rb           # Model for running events
│   └── runner.rb          # Model for runners
└── services/
    ├── event_scraper.rb   # Events scraper
    └── clax_parser.rb     # .clax file parser

spec/
├── models/
│   ├── event_spec.rb      # 15 tests
│   └── runner_spec.rb     # 11 tests
├── services/
│   ├── event_scraper_spec.rb  # 20 tests
│   └── clax_parser_spec.rb    # 12 tests
└── factories/
    ├── events.rb
    └── runners.rb
```

## Data Models

### Event

Stores running event information:

- `name`: Event name
- `event_date`: Event date
- `city`: City (filtered to "Santarém")
- `result_url`: Results page URL
- `clax_file_url`: .clax file (XML) URL
- `scraped_at`: Scraping timestamp

**Available scopes:**
- `from_santarem`: Only events from Santarém
- `recent`: Ordered by date descending
- `scraped`: Already processed events
- `not_scraped`: Pending events

### Runner

Stores runner data:

- `event_id`: Event reference
- `position`: Overall position
- `bib_number`: Bib number
- `name`: Runner name
- `club`: Club/team
- `gender`: Gender (M/F)
- `category`: Category (OVERALL, 40-49, 50-59, etc)
- `finish_time`: Finish time
- `average_pace`: Average pace
- `points`: Score
- `laps`: Number of laps
- `best_lap`: Best lap
- `distance`: Distance covered

**Available scopes:**
- `by_position`: Ordered by position
- `by_gender(gender)`: Filter by gender
- `by_category(category)`: Filter by category

## Filtering Criteria

The scraper automatically applies the following filters:

✅ **Included:**
- Events from "Santarém"
- Road running/walking events

❌ **Excluded:**
- Events from other cities
- Cycling, bike, MTB
- Swimming, open water
- Trail running
- Triathlon, duathlon

## Architecture and Design Patterns

The project follows Software Engineering best practices, applying several recognized **Design Patterns**:

### 1. Service Object Pattern

Isolates complex business logic into dedicated service classes.

```ruby
# app/services/event_scraper.rb
class EventScraper
  def scrape_events
    # Scraping logic isolated from Model
  end

  def save_events
    # Single responsibility: scraping and saving
  end
end

# Usage
scraper = EventScraper.new
scraper.save_events
```

**Benefits:**
- ✅ Single Responsibility Principle (SOLID)
- ✅ Reusable and testable code
- ✅ Lean models, focused on data

**Applied in:** `EventScraper`, `ClaxParser`

### 2. Dependency Injection

Injects dependencies via constructor, facilitating testing and reducing coupling.

```ruby
# app/services/clax_parser.rb
class ClaxParser
  def initialize(event)  # ← Injects dependency
    @event = event
  end

  def parse_and_save
    # Uses injected @event
  end
end

# Usage
parser = ClaxParser.new(event)
parser.parse_and_save
```

**Benefits:**
- ✅ Facilitates testing with mocks/stubs
- ✅ Low coupling
- ✅ Flexibility to swap implementations

**Applied in:** `ClaxParser`

### 3. Active Record Pattern

Encapsulates data and persistence logic in the same object.

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  has_many :runners

  validates :name, presence: true

  def mark_as_scraped!
    update(scraped_at: Time.current)
  end
end
```

**Benefits:**
- ✅ Object = Database record
- ✅ Complete SQL abstraction
- ✅ Rails native pattern

**Applied in:** `Event`, `Runner`

### 4. Query Object Pattern (via Scopes)

Encapsulates complex queries into reusable and composable scopes.

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  scope :from_santarem, -> { where(city: 'Santarém') }
  scope :recent, -> { order(event_date: :desc) }
  scope :scraped, -> { where.not(scraped_at: nil) }
  scope :not_scraped, -> { where(scraped_at: nil) }
end

# Composable usage
Event.from_santarem.recent.not_scraped
```

**Benefits:**
- ✅ Encapsulated and named queries
- ✅ Reusable and composable
- ✅ More readable code

**Applied in:** `Event` and `Runner` scopes

### 5. Factory Pattern

Creates test objects consistently and flexibly.

```ruby
# spec/factories/events.rb
FactoryBot.define do
  factory :event do
    name { "9th Road Race" }
    city { "Santarém" }

    trait :from_santarem do
      city { "Santarém" }
    end

    trait :cycling do
      name { "10th Mountain Cycling" }
    end
  end
end

# Usage
create(:event, :from_santarem)
create(:event, :cycling)
```

**Benefits:**
- ✅ Consistent fixture creation
- ✅ Traits for variations
- ✅ DRY in tests

**Applied in:** FactoryBot (tests)

### 6. Template Method Pattern

Defines algorithm structure with steps implemented by private methods.

```ruby
# app/services/clax_parser.rb
def parse_and_save
  return unless @event.clax_file_url.present?  # Guard clause

  xml_content = fetch_clax_file                # Step 1
  return unless xml_content

  parse_runners_from_xml(xml_content)          # Step 2
end

private

def fetch_clax_file
  # Specific implementation
end

def parse_runners_from_xml(xml)
  # Specific implementation
end
```

**Benefits:**
- ✅ Algorithm with well-defined steps
- ✅ Easy to extend/modify
- ✅ Organized code

**Applied in:** `ClaxParser#parse_and_save`

### 7. Strategy Pattern

Defines different filtering strategies that can be applied.

```ruby
# app/services/event_scraper.rb
def should_save_event?(event_data)
  return false unless event_data[:name].present?
  return false unless event_data[:city].present?

  # Strategy 1: City filter
  return false unless event_data[:city]&.match?(/santarém/i)

  # Strategy 2: Sport type filter
  name = event_data[:name].downcase
  excluded_terms = ['ciclismo', 'natação', 'trilha', 'triatlo', ...]
  excluded_terms.none? { |term| name.include?(term) }
end
```

**Benefits:**
- ✅ Configurable filter strategies
- ✅ Easy to add new criteria
- ✅ Separation of concerns

**Applied in:** `EventScraper#should_save_event?`

### 8. Null Object Pattern

Returns null values instead of raising exceptions, avoiding crashes.

```ruby
# app/services/event_scraper.rb
def parse_date(date_string)
  return nil unless date_string  # Implicit Null Object

  parts = date_string.split('/')
  return nil unless parts.length == 3

  Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
rescue StandardError => e
  Rails.logger.error("Error parsing date: #{e.message}")
  nil  # Returns nil instead of exception
end
```

**Benefits:**
- ✅ Avoids unexpected crashes
- ✅ Cleaner code (fewer nil checks)
- ✅ Graceful degradation

**Applied in:** Parsing methods in `EventScraper` and `ClaxParser`

### 9. Test Double Pattern

Uses mocks and stubs to isolate tests from external dependencies.

```ruby
# spec/services/clax_parser_spec.rb
context 'when CLAX file is accessible' do
  before do
    # HTTP request mock
    stub_request(:get, event.clax_file_url)
      .to_return(status: 200, body: sample_xml)
  end

  it 'creates runners from XML data' do
    expect { parser.parse_and_save }.to change { event.runners.count }.by(3)
  end
end

# VCR to record/replay real requests
context 'when website is accessible', vcr: { cassette_name: 'scraper' } do
  # Tests with recorded real requests
end
```

**Benefits:**
- ✅ Fast tests (no external requests)
- ✅ Deterministic tests
- ✅ Tests work offline

**Applied in:** Tests with WebMock and VCR

### 10. SOLID Principles

The project follows all five SOLID principles:

#### **S - Single Responsibility Principle**
Each class has a single responsibility:
- `EventScraper`: Only event scraping
- `ClaxParser`: Only XML parsing
- `Event`: Only event data and rules
- `Runner`: Only runner data and rules

#### **O - Open/Closed Principle**
Open for extension, closed for modification:
- New scopes can be added without modifying existing code
- New filter strategies can be added via configuration

#### **L - Liskov Substitution Principle**
Subtypes can replace their base types:
- `Event` and `Runner` can be replaced by any `ApplicationRecord`

#### **I - Interface Segregation Principle**
Small and specific interfaces:
- Services have minimal and focused public methods
- No forced unnecessary dependencies

#### **D - Dependency Inversion Principle**
Depend on abstractions, not implementations:
- `ClaxParser` depends on any object responding to `clax_file_url`
- Facilitates testing with mocks

### Layered Architecture

```
┌─────────────────────────────────────────┐
│         Service Layer                    │
│  (EventScraper, ClaxParser)             │ ← Service Object Pattern
│  - Complex business logic               │ ← Dependency Injection
│  - Operation orchestration              │ ← Template Method
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Model Layer                      │
│  (Event, Runner)                        │ ← Active Record Pattern
│  - Validations and associations         │ ← Query Object (Scopes)
│  - Business rules                       │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│         Database Layer                   │
│  (SQLite3)                              │
│  - Data persistence                     │
└─────────────────────────────────────────┘
```

### Pattern Summary

| Pattern | Where Applied | Main Benefit |
|---------|---------------|--------------|
| Service Object | `EventScraper`, `ClaxParser` | Isolates complex logic |
| Dependency Injection | `ClaxParser` | Facilitates testing |
| Active Record | `Event`, `Runner` | Data abstraction |
| Query Object | Scopes | Reusable queries |
| Factory | FactoryBot | Consistent fixtures |
| Template Method | `parse_and_save` | Structured algorithm |
| Strategy | `should_save_event?` | Flexible filters |
| Null Object | Parsing methods | Avoids crashes |
| Test Double | WebMock/VCR | Isolated tests |
| SOLID | Entire project | Maintainable code |

## Tests

The project has **58 tests** covering:

### Models (26 tests)
- Validations and associations
- Scopes and custom methods
- Data integrity

### Services (32 tests)
- Event scraping
- Filtering by sport type and city
- .clax file parsing
- Error handling
- Data validation

### Testing Tools
- **RSpec**: Testing framework
- **FactoryBot**: Fixtures
- **Faker**: Random data
- **VCR**: HTTP request recording
- **WebMock**: Request mocking
- **DatabaseCleaner**: Database cleanup between tests
- **Shoulda Matchers**: Validation matchers

## License

This project was developed for educational purposes and automation of public data collection.
