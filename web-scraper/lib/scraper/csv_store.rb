require 'csv'

module Scraper
  class CsvStore
    def initialize(path, headers)
      @path = path
      @headers = headers.map(&:to_sym)
      @rows = load_rows
    end

    attr_reader :rows

    def find(match)
      match = match.transform_values(&:to_s)
      rows.find { |row| match.all? { |key, value| row[key.to_sym].to_s == value } }
    end

    def next_id
      rows.map { |row| row[:id].to_i }.max.to_i + 1
    end

    def add(attributes)
      row = @headers.each_with_object({}) { |h, hash| hash[h] = attributes[h] }
      rows << row
      row
    end

    def save!
      CSV.open(@path, 'w') do |csv|
        csv << @headers
        rows.each { |row| csv << @headers.map { |h| row[h] } }
      end
    end

    private

    def load_rows
      return [] unless File.exist?(@path)

      CSV.read(@path, headers: true).map do |csv_row|
        @headers.each_with_object({}) do |h, hash|
          value = csv_row[h.to_s]
          hash[h] = (value.nil? || value == '') ? nil : value
        end
      end
    end
  end
end
