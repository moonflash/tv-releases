require 'rails_helper'

RSpec.describe ReleaseImportService, type: :service do
  let(:service) { described_class.new }

  describe '#import_upcoming_releases' do
    let(:mock_releases_data) do
      [
        {
          'date' => '2025-06-17',
          'time' => '22:00',
          'show_id' => 'show_123',
          'episode_id' => 'ep_456',
          'network_id' => 'net_789',
          'network_name' => 'HBO'
        },
        {
          'date' => '2025-06-18',
          'time' => '21:00',
          'show_id' => 'show_456',
          'episode_id' => 'ep_789',
          'network_id' => 'net_123',
          'network_name' => 'Netflix'
        }
      ]
    end

    let(:show_data) do
      {
        'title' => 'Game of Thrones',
        'description' => 'Epic fantasy series',
        'show_type' => 'Drama'
      }
    end

    let(:episode_data) do
      {
        'season' => 1,
        'episode' => 5,
        'summary' => 'An epic episode'
      }
    end

    before do
      # Mock all Crawl4aiService calls to prevent actual HTTP requests
      allow(Crawl4aiService).to receive(:extract).and_return(mock_releases_data, [])
      allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
      allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
    end

    it 'imports releases successfully' do
      result = service.import_upcoming_releases

      expect(result[:imported]).to eq(2)
      expect(result[:skipped]).to eq(0)
      expect(result[:errors]).to eq(0)
    end

    it 'creates the correct number of records' do
      expect {
        service.import_upcoming_releases
      }.to change(Network, :count).by(2)
        .and change(Show, :count).by(2)
        .and change(Episode, :count).by(2)
        .and change(Release, :count).by(2)
    end

    it 'creates releases with correct attributes' do
      service.import_upcoming_releases

      first_release = Release.first
      expect(first_release.air_date).to eq(Date.parse('2025-06-17'))
      expect(first_release.air_time.strftime('%H:%M')).to eq('22:00')
      expect(first_release.show.title).to eq('Game of Thrones')
    end

    context 'when releases already exist' do
      before do
        # Mock service calls for pre-existing release creation
        allow(Crawl4aiService).to receive(:extract_show).with('show_123').and_return(show_data)
        allow(Crawl4aiService).to receive(:extract_episode).with('ep_456').and_return(episode_data)
        
        # Create the first release before running import
        Release.find_or_create_from_crawl_data({
          'date' => '2025-06-17',
          'time' => '22:00',
          'show_id' => 'show_123',
          'episode_id' => 'ep_456',
          'network_id' => 'net_789',
          'network_name' => 'HBO'
        })
      end

      it 'skips existing releases' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(1) # Only the second one
        expect(result[:skipped]).to eq(1)  # The first one is skipped
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when data is beyond cutoff date' do
      let(:far_future_data) do
        [{
          'date' => (Date.current + 200.days).to_s,
          'time' => '22:00',
          'show_id' => 'show_123',
          'episode_id' => 'ep_456',
          'network_id' => 'net_789',
          'network_name' => 'HBO'
        }]
      end

      before do
        allow(Crawl4aiService).to receive(:extract).and_return(far_future_data, [])
        # Mock service calls even for cutoff dates to prevent HTTP requests
        allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
        allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
      end

      it 'stops processing when all releases are beyond cutoff' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when network creation fails' do
      let(:bad_data) do
        [{
          'date' => '2025-06-17',
          'time' => '22:00',
          'show_id' => 'show_123',
          'episode_id' => 'ep_456',
          'network_id' => '', # This will cause network creation to fail
          'network_name' => 'HBO'
        }]
      end

      before do
        allow(Crawl4aiService).to receive(:extract).and_return(bad_data, [])
        # Mock service calls even for failure scenarios
        allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
        allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
      end

      it 'handles network creation failures gracefully' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when show extraction fails' do
      before do
        # Override the show extraction to return empty data
        allow(Crawl4aiService).to receive(:extract_show).and_return({})
        allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
      end

      it 'handles show extraction failures gracefully' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(2)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when episode extraction fails' do
      before do
        # Override the episode extraction to return empty data
        allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
        allow(Crawl4aiService).to receive(:extract_episode).and_return({})
      end

      it 'handles episode extraction failures gracefully' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(2)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when show service raises exceptions' do
      before do
        allow(Crawl4aiService).to receive(:extract_show).and_raise(StandardError, 'Show service error')
        allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
      end

      it 'handles show service exceptions gracefully' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(2)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when episode service raises exceptions' do
      before do
        allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
        allow(Crawl4aiService).to receive(:extract_episode).and_raise(StandardError, 'Episode service error')
      end

      it 'handles episode service exceptions gracefully' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(2)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when there are processing errors' do
      before do
        # Mock service calls first
        allow(Crawl4aiService).to receive(:extract_show).and_return(show_data)
        allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
        # Then make the release creation fail
        allow(Release).to receive(:find_or_create_from_crawl_data).and_raise(StandardError, 'Processing error')
      end

      it 'handles processing errors gracefully' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to eq(2)
      end
    end
  end

  describe '#extract_with_retry' do
    let(:url) { 'https://example.com/test' }

    before do
      # Mock the service to prevent actual HTTP requests
      allow(Crawl4aiService).to receive(:extract).and_return([])
    end

    it 'returns data on first successful attempt' do
      allow(Crawl4aiService).to receive(:extract).and_return([{ 'test' => 'data' }])

      result = service.send(:extract_with_retry, url)
      expect(result).to eq([{ 'test' => 'data' }])
    end

    it 'retries when no data is returned' do
      allow(Crawl4aiService).to receive(:extract).and_return([], [], [{ 'test' => 'data' }])
      allow(service).to receive(:sleep) # Don't actually sleep in tests

      result = service.send(:extract_with_retry, url)
      expect(result).to eq([{ 'test' => 'data' }])
      expect(Crawl4aiService).to have_received(:extract).exactly(3).times
    end

    it 'gives up after max retries' do
      allow(Crawl4aiService).to receive(:extract).and_return([])
      allow(service).to receive(:sleep) # Don't actually sleep in tests

      result = service.send(:extract_with_retry, url)
      expect(result).to eq([])
      expect(Crawl4aiService).to have_received(:extract).exactly(6).times # 1 + 5 retries
    end
  end

  describe '#release_beyond_cutoff?' do
    let(:cutoff_date) { Date.current + 90.days }

    before do
      service.instance_variable_set(:@cutoff_date, cutoff_date)
    end

    it 'returns false for releases within cutoff' do
      release_data = { 'date' => (Date.current + 30.days).to_s }
      expect(service.send(:release_beyond_cutoff?, release_data)).to be false
    end

    it 'returns true for releases beyond cutoff' do
      release_data = { 'date' => (Date.current + 100.days).to_s }
      expect(service.send(:release_beyond_cutoff?, release_data)).to be true
    end

    it 'handles invalid date formats gracefully' do
      release_data = { 'date' => 'invalid-date' }
      expect(service.send(:release_beyond_cutoff?, release_data)).to be false
    end
  end
end
