require 'rails_helper'

RSpec.describe Show, type: :model do
  let(:country) { Country.create!(name: 'United States', shortcode: 'US') }
  let(:network) { Network.create!(name: 'HBO', external_id: 'hbo_123', country: country) }

  describe 'validations' do
    it 'validates presence of title' do
      show = Show.new(network: network, external_id: 'show_123')
      show.valid?
      expect(show.errors[:title]).to include("can't be blank")
    end

    it 'validates presence of external_id' do
      show = Show.new(title: 'Game of Thrones', network: network)
      show.valid?
      expect(show.errors[:external_id]).to include("can't be blank")
    end

    it 'validates uniqueness of external_id' do
      Show.create!(title: 'Game of Thrones', external_id: 'show_123', network: network)
      duplicate = Show.new(title: 'House of Dragons', external_id: 'show_123', network: network)
      duplicate.valid?
      expect(duplicate.errors[:external_id]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it 'belongs to network' do
      show = Show.new
      expect(show).to respond_to(:network)
    end

    it 'has many episodes' do
      show = Show.new
      expect(show).to respond_to(:episodes)
    end

    it 'has many releases through episodes' do
      show = Show.new
      expect(show).to respond_to(:releases)
    end
  end

  describe '.find_or_create_from_external_id' do
    let(:show_data) do
      {
        'title' => 'Game of Thrones',
        'description' => 'Epic fantasy series',
        'show_type' => 'Drama',
        'official_site_url' => 'https://hbo.com/got',
        'genres' => ['Fantasy', 'Drama'],
        'vote' => 9.2
      }
    end

    before do
      # Mock the service call to prevent actual HTTP requests
      allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
    end

    it 'finds existing show by external_id' do
      existing = Show.create!(
        title: 'Game of Thrones',
        external_id: 'show_123',
        network: network
      )
      
      result = Show.find_or_create_from_external_id('show_123', network)
      expect(result).to eq(existing)
      
      # Ensure service was not called for existing show
      expect(Crawl4aiService).not_to have_received(:extract_show)
    end

    it 'creates new show when none exists' do
      expect {
        Show.find_or_create_from_external_id('show_123', network)
      }.to change(Show, :count).by(1)
      
      # Ensure service was called for new show
      expect(Crawl4aiService).to have_received(:extract_show).with('show_123')
    end

    it 'creates show with correct attributes' do
      show = Show.find_or_create_from_external_id('show_123', network)
      
      expect(show.title).to eq('Game of Thrones')
      expect(show.description).to eq('Epic fantasy series')
      expect(show.show_type).to eq('Drama')
      expect(show.official_site_url).to eq('https://hbo.com/got')
      expect(show.genres).to eq('Fantasy, Drama')
      expect(show.vote).to eq(9.2)
      expect(show.network).to eq(network)
    end

    it 'returns nil when external_id is blank' do
      result = Show.find_or_create_from_external_id('', network)
      expect(result).to be_nil
      
      # Ensure service was not called
      expect(Crawl4aiService).not_to have_received(:extract_show)
    end

    it 'returns nil when show data is blank' do
      allow(Crawl4aiService).to receive(:extract_show).with('show_123').and_return({})
      
      result = Show.find_or_create_from_external_id('show_123', network)
      expect(result).to be_nil
    end

    it 'returns nil when title is missing from show data' do
      show_data_without_title = show_data.except('title')
      allow(Crawl4aiService).to receive(:extract_show).with('show_123').and_return(show_data_without_title)
      
      result = Show.find_or_create_from_external_id('show_123', network)
      expect(result).to be_nil
    end

    it 'handles service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_show).with('show_123').and_raise(StandardError, 'Service error')
      
      result = Show.find_or_create_from_external_id('show_123', network)
      expect(result).to be_nil
    end
  end
end 