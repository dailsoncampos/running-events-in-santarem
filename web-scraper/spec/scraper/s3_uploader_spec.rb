require 'spec_helper'
require 'tmpdir'

RSpec.describe Scraper::S3Uploader do
  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, 'test.csv')
      File.write(@path, "id,name\n1,foo\n")
      example.run
    end
  end

  describe 'without a bucket configured' do
    let(:uploader) { described_class.new(bucket: nil) }

    it 'is not enabled' do
      expect(uploader).not_to be_enabled
    end

    it 'does not touch S3' do
      expect(Aws::S3::Client).not_to receive(:new).and_call_original
      uploader.upload(@path, 'raw/events.csv')
    end
  end

  describe 'with a bucket configured' do
    let(:client) { Aws::S3::Client.new(stub_responses: true, region: 'us-east-1') }
    let(:uploader) { described_class.new(bucket: 'my-bucket') }

    before { allow(Aws::S3::Client).to receive(:new).and_return(client) }

    it 'is enabled' do
      expect(uploader).to be_enabled
    end

    it 'uploads the file body to the given bucket and key' do
      uploader.upload(@path, 'raw/events.csv')

      expect(client.api_requests.last[:params]).to include(
        bucket: 'my-bucket',
        key: 'raw/events.csv',
        body: File.read(@path)
      )
    end

    it 'lets a service error propagate' do
      client.stub_responses(:put_object, 'NoSuchBucket')

      expect { uploader.upload(@path, 'raw/events.csv') }.to raise_error(Aws::S3::Errors::NoSuchBucket)
    end
  end
end
