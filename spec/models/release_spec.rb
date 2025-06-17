require 'rails_helper'

RSpec.describe Release, type: :model do
  let(:country) { Country.create!(name: 'United States', shortcode: 'US') }
  let(:network) { Network.create!(name: 'HBO', external_id: 'hbo_123', country: country) }
  let(:show) { Show.create!(title: 'Game of Thrones', external_id: 'show_123', network: network) }
  let(:episode) { Episode.create!(season_number: 1, episode_number: 5, external_id: 'ep_123', show: show) }

  describe 'validations' do
    it 'validates presence of air_date' do
      release = Release.new(air_time: '20:00:00', episode: episode)
      release.valid?
      expect(release.errors[:air_date]).to include("can't be blank")
    end

    it 'validates presence of air_time' do
      release = Release.new(air_date: Date.current, episode: episode)
      release.valid?
      expect(release.errors[:air_time]).to include("can't be blank")
    end

    it 'validates uniqueness of air_date and air_time within episode' do
      Release.create!(air_date: '2025-06-15', air_time: '20:00:00', episode: episode)
      duplicate = Release.new(air_date: '2025-06-15', air_time: '20:00:00', episode: episode)
      duplicate.valid?
      expect(duplicate.errors[:air_date]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it 'belongs to episode' do
      release = Release.new
      expect(release).to respond_to(:episode)
    end
  end

  describe 'scopes' do
    let(:past_episode) { Episode.create!(season_number: 10, episode_number: 1, external_id: 'ep_past_unique', show: show) }
    let(:today_episode) { Episode.create!(season_number: 10, episode_number: 2, external_id: 'ep_today_unique', show: show) }
    let(:future_episode) { Episode.create!(season_number: 10, episode_number: 3, external_id: 'ep_future_unique', show: show) }

    let!(:past_release) { Release.create!(air_date: 1.day.ago, air_time: '20:00:00', episode: past_episode) }
    let!(:today_release) { Release.create!(air_date: Date.current, air_time: '20:00:00', episode: today_episode) }
    let!(:future_release) { Release.create!(air_date: 5.days.from_now, air_time: '20:00:00', episode: future_episode) }

    describe '.upcoming' do
      it 'returns releases from today onwards' do
        upcoming = Release.upcoming
        expect(upcoming).to include(today_release, future_release)
        expect(upcoming).not_to include(past_release)
      end
    end

    describe '.within_days' do
      it 'returns releases within specified days from today' do
        within_3_days = Release.within_days(3)
        expect(within_3_days).to include(today_release)
        expect(within_3_days).not_to include(past_release, future_release)
      end
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
        expect(second_release).to eq(first_release)
      }.not_to change(Release, :count)
    end

    it 'returns nil when network creation fails' do
      # Make network creation fail by not providing external_id
      bad_data = crawl_data.except('network_id')
      result = Release.find_or_create_from_crawl_data(bad_data)
      expect(result).to be_nil
    end

    it 'returns nil when show creation fails' do
      # Make show creation fail
      allow(Crawl4aiService).to receive(:extract_show).and_return({})
      result = Release.find_or_create_from_crawl_data(crawl_data)
      expect(result).to be_nil
    end

    it 'returns nil when episode creation fails' do
      # Make episode creation fail
      allow(Crawl4aiService).to receive(:extract_episode).and_return({})
      result = Release.find_or_create_from_crawl_data(crawl_data)
      expect(result).to be_nil
    end

    it 'handles show service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_show).and_raise(StandardError, 'Show service error')
      result = Release.find_or_create_from_crawl_data(crawl_data)
      expect(result).to be_nil
    end

    it 'handles episode service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_episode).and_raise(StandardError, 'Episode service error')
      result = Release.find_or_create_from_crawl_data(crawl_data)
      expect(result).to be_nil
    end

    it 'calls service methods with correct parameters' do
      Release.find_or_create_from_crawl_data(crawl_data)
      
      expect(Crawl4aiService).to have_received(:extract_show).with('show_456')
      expect(Crawl4aiService).to have_received(:extract_episode).with('ep_456')
    end
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
