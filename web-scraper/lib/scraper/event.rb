module Scraper
  class Event
    ATTRIBUTES = %i[id name event_date city result_url clax_file_url scraped_at].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(attributes = {})
      ATTRIBUTES.each { |attr| public_send("#{attr}=", attributes[attr]) }
    end

    def scraped?
      !scraped_at.to_s.empty?
    end

    def to_h
      ATTRIBUTES.each_with_object({}) { |attr, hash| hash[attr] = public_send(attr) }
    end
  end
end
