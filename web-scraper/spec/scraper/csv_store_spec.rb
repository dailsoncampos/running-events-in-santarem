require 'spec_helper'
require 'tmpdir'

RSpec.describe Scraper::CsvStore do
  around do |example|
    Dir.mktmpdir do |dir|
      @path = File.join(dir, 'test.csv')
      example.run
    end
  end

  let(:store) { described_class.new(@path, %i[id name value]) }

  it 'starts empty when the file does not exist yet' do
    expect(store.rows).to eq([])
  end

  it 'adds and finds a row' do
    store.add(id: 1, name: 'foo', value: '10')
    expect(store.find(name: 'foo')).to include(name: 'foo', value: '10')
  end

  it 'returns nil from find when nothing matches' do
    store.add(id: 1, name: 'foo', value: '10')
    expect(store.find(name: 'bar')).to be_nil
  end

  it 'increments next_id based on existing rows' do
    store.add(id: 5, name: 'foo', value: '10')
    expect(store.next_id).to eq(6)
  end

  it 'starts next_id at 1 when empty' do
    expect(store.next_id).to eq(1)
  end

  it 'persists rows to disk and reloads them on the next instance' do
    store.add(id: 1, name: 'foo', value: '10')
    store.save!

    reloaded = described_class.new(@path, %i[id name value])
    expect(reloaded.rows).to eq([{ id: '1', name: 'foo', value: '10' }])
  end

  it 'normalizes blank CSV cells to nil on reload' do
    store.add(id: 1, name: 'foo', value: nil)
    store.save!

    reloaded = described_class.new(@path, %i[id name value])
    expect(reloaded.rows.first[:value]).to be_nil
  end
end
