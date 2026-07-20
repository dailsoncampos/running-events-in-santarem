module Scraper
  class Runner
    ATTRIBUTES = %i[
      id event_id position bib_number name club gender category
      finish_time average_pace points laps best_lap distance
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(attributes = {})
      ATTRIBUTES.each { |attr| public_send("#{attr}=", attributes[attr]) }
      self.position = position.to_i if position
      self.points = points.to_i if points
      self.laps = laps.to_i if laps
    end

    def to_h
      ATTRIBUTES.each_with_object({}) { |attr, hash| hash[attr] = public_send(attr) }
    end
  end
end
