require 'rails_helper'

RSpec.describe ReleaseImportService, type: :service do
  let(:service) { described_class.new }

  describe '#import_upcoming_releases' do
    let(:country) { create(:country) }
    let(:network) { create(:network, country: country) }
    let(:show) { create(:show, network: network) }
    let(:episode) { create(:episode, show: show) }

    before do
      allow(Crawl4aiService).to receive(:extract).and_return([
        { 'date' => '2025-06-17', 'time' => '20:00', 'show_id' => show.external_id, 'episode_id' => episode.external_id, 'network_id' => network.external_id }
      ], [])
    end

    it 'imports releases successfully' do
      result = service.import_upcoming_releases
      expect(result[:imported]).to eq(1) # One release imported
      expect(result[:skipped]).to eq(0)
      expect(result[:errors]).to eq(0)
    end

    it 'creates the correct number of records' do
      expect {
        service.import_upcoming_releases
      }.to change(Release, :count).by(1)
    end

    it 'creates releases with correct attributes' do
      service.import_upcoming_releases
      first_release = Release.first
      expect(first_release.air_date).to eq(Date.parse('2025-06-17'))
      expect(first_release.air_time.strftime('%H:%M:%S')).to eq('20:00:00')
      expect(first_release.episode).to eq(episode)
    end

    context 'when releases already exist' do
      before do
        create(:release, air_date: '2025-06-17', air_time: '20:00', episode: episode)
      end

      it 'skips existing releases' do
        result = service.import_upcoming_releases
        expect(result[:imported]).to eq(0) # No new records imported
        expect(result[:skipped]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when show extraction fails' do
      before do
        allow(Crawl4aiService).to receive(:extract_show).and_return({})
      end

      it 'handles show extraction failures gracefully' do
        result = service.import_upcoming_releases
        expect(result[:imported]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when episode extraction fails' do
      before do
        allow(Crawl4aiService).to receive(:extract_episode).and_return({})
      end

      it 'handles episode extraction failures gracefully' do
        result = service.import_upcoming_releases
        expect(result[:imported]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when show service raises exceptions' do
      before do
        allow(Crawl4aiService).to receive(:extract_show).and_raise(StandardError)
      end

      it 'handles show service exceptions gracefully' do
        result = service.import_upcoming_releases
        expect(result[:imported]).to eq(1)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when episode service raises exceptions' do
      before do
        allow(Crawl4aiService).to receive(:extract_episode).and_raise(StandardError)
      end

      it 'handles episode service exceptions gracefully' do
        result = service.import_upcoming_releases
        expect(result[:imported]).to eq(1)
        expect(result[:errors]).to eq(0)
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
      allow(Crawl4aiService).to receive(:extract).and_return([ { 'test' => 'data' } ])

      result = service.send(:extract_with_retry, url)
      expect(result).to eq([ { 'test' => 'data' } ])
    end

    it 'retries when no data is returned' do
      allow(Crawl4aiService).to receive(:extract).and_return([], [], [ { 'test' => 'data' } ])
      allow(service).to receive(:sleep) # Don't actually sleep in tests

      result = service.send(:extract_with_retry, url)
      expect(result).to eq([ { 'test' => 'data' } ])
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
