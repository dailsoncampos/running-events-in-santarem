FROM ruby:3.2.2

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile ./
RUN bundle install

COPY . .

CMD ["bundle", "exec", "rake", "scrape:all"]
