require 'aws-sdk-s3'

module Scraper
  class S3Uploader
    def initialize(bucket: ENV['S3_BUCKET'],
                    region: ENV.fetch('AWS_REGION', 'us-east-1'),
                    endpoint: ENV['S3_ENDPOINT_URL'])
      @bucket = bucket
      @region = region
      @endpoint = endpoint
    end

    def enabled?
      !@bucket.to_s.empty?
    end

    def upload(local_path, key)
      return unless enabled?

      Scraper.logger.info("Uploading #{local_path} to s3://#{@bucket}/#{key}")
      client.put_object(bucket: @bucket, key: key, body: File.read(local_path))
    rescue Aws::Errors::ServiceError => e
      Scraper.logger.error("Failed to upload #{local_path} to s3://#{@bucket}/#{key}: #{e.message}")
      raise
    end

    private

    def client
      @client ||= Aws::S3::Client.new(
        region: @region,
        **(@endpoint.to_s.empty? ? {} : { endpoint: @endpoint })
      )
    end
  end
end
