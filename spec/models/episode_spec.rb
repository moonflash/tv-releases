require 'rails_helper'

RSpec.describe Episode, type: :model do
  let(:country) { Country.create!(name: 'United States', shortcode: 'US') }
  let(:network) { Network.create!(name: 'HBO', external_id: 'hbo_123', country: country) }
  let(:show) { Show.create!(title: 'Game of Thrones', external_id: 'show_123', network: network) }

  describe 'validations' do
    it 'validates presence of season_number' do
      episode = Episode.new(episode_number: 1, external_id: 'ep_123', show: show)
      episode.valid?
      expect(episode.errors[:season_number]).to include("can't be blank")
    end

    it 'validates presence of episode_number' do
      episode = Episode.new(season_number: 1, external_id: 'ep_123', show: show)
      episode.valid?
      expect(episode.errors[:episode_number]).to include("can't be blank")
    end

    it 'validates presence of external_id' do
      episode = Episode.new(season_number: 1, episode_number: 1, show: show)
      episode.valid?
      expect(episode.errors[:external_id]).to include("can't be blank")
    end

    it 'validates uniqueness of external_id' do
      Episode.create!(season_number: 1, episode_number: 1, external_id: 'ep_123', show: show)
      duplicate = Episode.new(season_number: 1, episode_number: 2, external_id: 'ep_123', show: show)
      duplicate.valid?
      expect(duplicate.errors[:external_id]).to include('has already been taken')
    end

    it 'validates uniqueness of season and episode within show' do
      Episode.create!(season_number: 1, episode_number: 1, external_id: 'ep_123', show: show)
      duplicate = Episode.new(season_number: 1, episode_number: 1, external_id: 'ep_456', show: show)
      duplicate.valid?
      expect(duplicate.errors[:season_number]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it 'belongs to show' do
      episode = Episode.new
      expect(episode).to respond_to(:show)
    end

    it 'has many releases' do
      episode = Episode.new
      expect(episode).to respond_to(:releases)
    end
  end

  describe '.find_or_create_from_external_id' do
    let(:episode_data) do
      {
        'season' => 1,
        'episode' => 5,
        'airdate' => '2025-06-15',
        'runtime' => 60,
        'summary' => 'An epic episode'
      }
    end

    before do
      # Mock the service call to prevent actual HTTP requests
      allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
    end

    it 'finds existing episode by external_id' do
      existing = Episode.create!(
        season_number: 1,
        episode_number: 5,
        external_id: 'ep_123',
        show: show
      )
      
      result = Episode.find_or_create_from_external_id('ep_123', show)
      expect(result).to eq(existing)
      
      # Ensure service was not called for existing episode
      expect(Crawl4aiService).not_to have_received(:extract_episode)
    end

    it 'creates new episode when none exists' do
      expect {
        Episode.find_or_create_from_external_id('ep_123', show)
      }.to change(Episode, :count).by(1)
      
      # Ensure service was called for new episode
      expect(Crawl4aiService).to have_received(:extract_episode).with('ep_123')
    end

    it 'creates episode with correct attributes' do
      episode = Episode.find_or_create_from_external_id('ep_123', show)
      
      expect(episode.season_number).to eq(1)
      expect(episode.episode_number).to eq(5)
      expect(episode.airdate).to eq(Date.parse('2025-06-15'))
      expect(episode.runtime).to eq(60)
      expect(episode.summary).to eq('An epic episode')
      expect(episode.show).to eq(show)
    end

    it 'returns nil when external_id is blank' do
      result = Episode.find_or_create_from_external_id('', show)
      expect(result).to be_nil
      
      # Ensure service was not called
      expect(Crawl4aiService).not_to have_received(:extract_episode)
    end

    it 'returns nil when episode data is blank' do
      allow(Crawl4aiService).to receive(:extract_episode).with('ep_123').and_return({})
      
      result = Episode.find_or_create_from_external_id('ep_123', show)
      expect(result).to be_nil
    end

    it 'returns nil when season is missing from episode data' do
      bad_data = episode_data.except('season')
      allow(Crawl4aiService).to receive(:extract_episode).with('ep_123').and_return(bad_data)
      
      result = Episode.find_or_create_from_external_id('ep_123', show)
      expect(result).to be_nil
    end

    it 'returns nil when episode number is missing from episode data' do
      bad_data = episode_data.except('episode')
      allow(Crawl4aiService).to receive(:extract_episode).with('ep_123').and_return(bad_data)
      
      result = Episode.find_or_create_from_external_id('ep_123', show)
      expect(result).to be_nil
    end

    it 'handles service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_episode).with('ep_123').and_raise(StandardError, 'Service error')
      
      result = Episode.find_or_create_from_external_id('ep_123', show)
      expect(result).to be_nil
    end
  end

  describe '#title' do
    it 'formats title correctly' do
      episode = Episode.new(season_number: 1, episode_number: 5)
      expect(episode.title).to eq('S01E05')
    end

    it 'formats double digit numbers correctly' do
      episode = Episode.new(season_number: 12, episode_number: 25)
      expect(episode.title).to eq('S12E25')
    end
  end
end 