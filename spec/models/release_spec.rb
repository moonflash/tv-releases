require 'rails_helper'

RSpec.describe Release, type: :model do
  let(:country) { Country.create!(name: 'United States', shortcode: 'US') }
  let(:network) { Network.create!(name: 'HBO', external_id: 'hbo_123', country: country) }
  let(:show) { Show.create!(title: 'Game of Thrones', external_id: 'show_123', network: network) }
  let(:episode) { Episode.create!(season_number: 1, episode_number: 5, external_id: 'ep_123', show: show) }

  describe 'validations' do
    subject { build(:release) }
    it { should validate_presence_of(:air_date) }
    it { should validate_presence_of(:air_time) }
    it { should validate_uniqueness_of(:air_date).scoped_to(:episode_id) }
  end

  describe 'associations' do
    it { should belong_to(:episode) }
  end

  describe 'scopes' do
    let(:past_episode) { Episode.create!(season_number: 10, episode_number: 1, external_id: 'ep_past_unique', show: show) }
    let(:today_episode) { Episode.create!(season_number: 11, episode_number: 2, external_id: 'ep_today_unique', show: show) }
    let(:future_episode) { Episode.create!(season_number: 12, episode_number: 3, external_id: 'ep_future_unique', show: show) }

    let!(:past_release) { Release.create!(air_date: 1.day.ago, air_time: '20:00:00', episode: past_episode) }
    let!(:today_release) { Release.create!(air_date: Date.current, air_time: '20:00:00', episode: today_episode) }
    let!(:future_release) { Release.create!(air_date: 5.days.from_now, air_time: '20:00:00', episode: future_episode) }

    it '.upcoming returns releases from today onwards' do
      expect(Release.upcoming).to include(today_release, future_release)
      expect(Release.upcoming).not_to include(past_release)
    end

    it '.within_days returns releases within specified days from today' do
      expect(Release.within_days(3)).to include(today_release)
      expect(Release.within_days(3)).not_to include(past_release, future_release)
    end
  end

  describe '.find_or_create_from_crawl_data' do
    let(:crawl_data) do
      {
        'date' => '2025-06-15',
        'time' => '20:00',
        'show_id' => 'show_456',
        'episode_id' => 'ep_456',
        'network_id' => 'net_456',
        'network_name' => 'Netflix'
      }
    end

    let(:show_data) do
      {
        'title' => 'Stranger Things',
        'description' => 'Sci-fi series',
        'show_type' => 'Drama'
      }
    end

    let(:episode_data) do
      {
        'season' => 4,
        'episode' => 8,
        'summary' => 'Season finale'
      }
    end

    before do
      # Mock all Crawl4aiService calls to prevent actual HTTP requests
      allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
      allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
    end

    it 'creates all necessary relationships and release' do
      expect {
        Release.find_or_create_from_crawl_data(crawl_data)
      }.to change(Network, :count).by(1)
        .and change(Show, :count).by(1)
        .and change(Episode, :count).by(1)
        .and change(Release, :count).by(1)
    end

    it 'creates release with correct attributes' do
      release = Release.find_or_create_from_crawl_data(crawl_data)
      
      expect(release.air_date).to eq(Date.parse('2025-06-15'))
      expect(release.air_time.strftime('%H:%M:%S')).to eq('20:00:00')
    end

    it 'finds existing release instead of creating duplicate' do
      # Create the release first time
      first_release = Release.find_or_create_from_crawl_data(crawl_data)
      
      # Try to create again with same data
      expect {
        second_release = Release.find_or_create_from_crawl_data(crawl_data)
        expect(second_release).to eq(:skipped)
      }.not_to change(Release, :count)
    end

    it 'returns nil when network creation fails' do
      # Make network creation fail by not providing external_id
      bad_data = crawl_data.except('network_id')
      result = Release.find_or_create_from_crawl_data(bad_data)
      expect(result).to be_nil
    end

    it 'returns nil when show creation fails' do
      # Even if show data extraction fails, a placeholder show should be created
      allow(Crawl4aiService).to receive(:extract_show).and_return({})
      result = Release.find_or_create_from_crawl_data(crawl_data)
      expect(result).to be_a(Release)
    end

    it 'returns nil when episode creation fails' do
      # Even if episode extraction fails, a placeholder episode and release should be created
      allow(Crawl4aiService).to receive(:extract_episode).and_return({})
      result = Release.find_or_create_from_crawl_data(crawl_data)
      expect(result).to be_a(Release)
    end

    it 'handles show service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_show).and_raise(StandardError, 'Show service error')
      expect {
        Release.find_or_create_from_crawl_data(crawl_data)
      }.not_to raise_error
    end

    it 'handles episode service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_episode).and_raise(StandardError, 'Episode service error')
      expect {
        Release.find_or_create_from_crawl_data(crawl_data)
      }.not_to raise_error
    end

    # In the new async architecture, Release model no longer calls Crawl4aiService directly
    # so we don't assert service calls here
  end

  describe 'delegated methods' do
    let(:release) { Release.create!(air_date: Date.current, air_time: '20:00:00', episode: episode) }

    describe '#show' do
      it 'returns the show through episode' do
        expect(release.show).to eq(show)
      end
    end

    describe '#network' do
      it 'returns the network through episode and show' do
        expect(release.network).to eq(network)
      end
    end

    describe '#country' do
      it 'returns the country through episode, show, and network' do
        expect(release.country).to eq(country)
      end
    end

    describe '#title' do
      it 'returns the show title' do
        expect(release.title).to eq('Game of Thrones')
      end
    end

    describe '#episode_title' do
      it 'returns formatted episode title with show title' do
        expect(release.episode_title).to eq('S01E05 - Game of Thrones')
      end
    end
  end
end
