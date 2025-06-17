require 'rails_helper'

RSpec.describe ReleaseImportService, type: :service do
  let(:service) { described_class.new }
  let(:sample_crawl_data) do
    [
      {
        'title' => 'Game of Thrones',
        'date' => '2024-01-15',
        'time' => '21:00',
        'channel' => 'HBO',
        'episode' => {
          'season' => 8,
          'number' => 1,
          'title' => 'The Last Watch'
        }
      },
      {
        'title' => 'Breaking Bad',
        'date' => '2024-01-16',
        'time' => '22:00',
        'channel' => 'AMC',
        'episode' => {
          'season' => 5,
          'number' => 16,
          'title' => 'Felina'
        }
      }
    ]
  end

  describe '.import_upcoming_releases' do
    it 'delegates to an instance' do
      expect_any_instance_of(described_class).to receive(:import_upcoming_releases)
      described_class.import_upcoming_releases
    end
  end

  describe '#import_upcoming_releases' do
    before do
      allow(Crawl4aiService).to receive(:extract).and_return([])
    end

    it 'logs the start of import' do
      expect(Rails.logger).to receive(:info).with('[ReleaseImportService] Starting import of upcoming releases')
      expect(Rails.logger).to receive(:info).with('[ReleaseImportService] Processing page 1')
      expect(Rails.logger).to receive(:info).with('[ReleaseImportService] No data returned for page 1, stopping')
      expect(Rails.logger).to receive(:info).with(match(/Import completed:/))
      expect(Rails.logger).to receive(:info).with('  - Imported: 0 releases')
      expect(Rails.logger).to receive(:info).with('  - Skipped: 0 duplicates')
      expect(Rails.logger).to receive(:info).with('  - Errors: 0 errors')
      service.import_upcoming_releases
    end

    context 'when no data is returned' do
      it 'stops after first page' do
        expect(Crawl4aiService).to receive(:extract).once.with('https://www.tvmaze.com/countdown?page=1')
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when data is returned' do
      before do
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=1')
          .and_return(sample_crawl_data)
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=2')
          .and_return([])
      end

      it 'processes releases and creates them' do
        expect {
          service.import_upcoming_releases
        }.to change(Release, :count).by(2)
          .and change(Channel, :count).by(2)
      end

      it 'returns correct statistics' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(2)
        expect(result[:skipped]).to eq(0)
        expect(result[:errors]).to eq(0)
      end
    end

    context 'when releases are beyond cutoff date' do
      let(:future_data) do
        [ {
          'title' => 'Future Show',
          'date' => (Date.current + 100.days).to_s,
          'time' => '21:00',
          'channel' => 'HBO',
          'episode' => { 'season' => 1, 'number' => 1, 'title' => 'Pilot' }
        } ]
      end

      before do
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=1')
          .and_return(future_data)
      end

      it 'stops processing when all releases are beyond cutoff' do
        result = service.import_upcoming_releases

        expect(result[:imported]).to eq(0)
        expect(Release.count).to eq(0)
      end
    end

    context 'when duplicate releases exist' do
      let!(:existing_release) do
        channel = Channel.create!(name: 'HBO')
        Release.create!(
          title: 'Game of Thrones',
          air_date: Date.parse('2024-01-15'),
          air_time: '21:00:00',
          season_number: 8,
          episode_number: 1,
          episode_title: 'The Last Watch',
          channel: channel
        )
      end

      before do
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=1')
          .and_return([ sample_crawl_data.first ])
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=2')
          .and_return([])
      end

      it 'skips duplicate releases' do
        expect {
          result = service.import_upcoming_releases
          expect(result[:skipped]).to eq(1)
          expect(result[:imported]).to eq(0)
        }.not_to change(Release, :count)
      end
    end

    context 'when errors occur' do
      before do
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=1')
          .and_return([ { 'invalid' => 'data' } ])
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=2')
          .and_return([])
      end

      it 'handles errors gracefully and continues processing' do
        expect(Rails.logger).to receive(:error).at_least(:once)

        result = service.import_upcoming_releases
        expect(result[:errors]).to be > 0
      end
    end

    context 'when crawl service returns empty data with retries' do
      before do
        # Mock empty responses for retries, then return data
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=1')
          .and_return([], [], sample_crawl_data) # Empty twice, then data
        allow(Crawl4aiService).to receive(:extract)
          .with('https://www.tvmaze.com/countdown?page=2')
          .and_return([])
        allow(service).to receive(:sleep) # Mock sleep to speed up tests
      end

      it 'retries and eventually succeeds' do
        expect(Crawl4aiService).to receive(:extract).exactly(4).times # 3 for page 1, 1 for page 2
        expect(Rails.logger).to receive(:warn).with(match(/retrying in 30 seconds/))
        expect(Rails.logger).to receive(:warn).with(match(/retrying in 60 seconds/))
        expect(Rails.logger).to receive(:info).with(match(/Successfully retrieved 2 releases/))

        result = service.import_upcoming_releases
        expect(result[:imported]).to eq(2)
      end
    end

    context 'when crawl service exhausts all retries' do
      before do
        # Mock all retries returning empty
        allow(Crawl4aiService).to receive(:extract).and_return([])
        allow(service).to receive(:sleep) # Mock sleep to speed up tests
      end

      it 'gives up after max retries' do
        expect(Crawl4aiService).to receive(:extract).exactly(6).times # 1 + 5 retries
        expect(Rails.logger).to receive(:warn).with(match(/No releases found after 6 attempts/))

        result = service.import_upcoming_releases
        expect(result[:imported]).to eq(0)
      end
    end
  end

  describe '#extract_with_retry' do
    context 'when service returns data immediately' do
      before do
        allow(Crawl4aiService).to receive(:extract).and_return(sample_crawl_data)
      end

      it 'returns data without retrying' do
        expect(Crawl4aiService).to receive(:extract).once
        expect(service).not_to receive(:sleep)

        result = service.send(:extract_with_retry, 'https://example.com')
        expect(result).to eq(sample_crawl_data)
      end
    end

    context 'when service returns empty data then succeeds' do
      before do
        allow(Crawl4aiService).to receive(:extract).and_return([], sample_crawl_data)
        allow(service).to receive(:sleep)
      end

      it 'retries with correct delay' do
        expect(Crawl4aiService).to receive(:extract).twice
        expect(service).to receive(:sleep).with(30).once
        expect(Rails.logger).to receive(:warn).with(match(/retrying in 30 seconds/))
        expect(Rails.logger).to receive(:info).with(match(/Successfully retrieved 2 releases/))

        result = service.send(:extract_with_retry, 'https://example.com')
        expect(result).to eq(sample_crawl_data)
      end
    end

    context 'when service always returns empty data' do
      before do
        allow(Crawl4aiService).to receive(:extract).and_return([])
        allow(service).to receive(:sleep)
      end

      it 'exhausts all retries with correct delays' do
        expect(Crawl4aiService).to receive(:extract).exactly(6).times
        expect(service).to receive(:sleep).with(30).once
        expect(service).to receive(:sleep).with(60).once
        expect(service).to receive(:sleep).with(90).once
        expect(service).to receive(:sleep).with(120).once
        expect(service).to receive(:sleep).with(150).once
        expect(Rails.logger).to receive(:warn).with(match(/No releases found after 6 attempts/))

        result = service.send(:extract_with_retry, 'https://example.com')
        expect(result).to eq([])
      end
    end
  end

  describe '#find_or_create_channel' do
    context 'when channel name is blank' do
      it 'returns nil' do
        expect(service.send(:find_or_create_channel, '')).to be_nil
        expect(service.send(:find_or_create_channel, nil)).to be_nil
      end
    end

    context 'when channel name is provided' do
      it 'delegates to Channel.find_or_create_by_fuzzy_name' do
        expect(Channel).to receive(:find_or_create_by_fuzzy_name).with('HBO')
        service.send(:find_or_create_channel, 'HBO')
      end
    end

    context 'when an error occurs' do
      before do
        allow(Channel).to receive(:find_or_create_by_fuzzy_name).and_raise(StandardError.new('Database error'))
      end

      it 'logs the error and returns nil' do
        expect(Rails.logger).to receive(:error).with("[ReleaseImportService] Error finding/creating channel 'HBO': Database error")

        result = service.send(:find_or_create_channel, 'HBO')
        expect(result).to be_nil
      end
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

    it 'returns false for missing date' do
      release_data = {}
      expect(service.send(:release_beyond_cutoff?, release_data)).to be false
    end

    it 'handles invalid date format' do
      release_data = { 'date' => 'invalid-date' }
      expect(Rails.logger).to receive(:warn).with("[ReleaseImportService] Invalid date format: invalid-date")
      expect(service.send(:release_beyond_cutoff?, release_data)).to be false
    end
  end

  describe '#beyond_cutoff_date?' do
    let(:cutoff_date) { Date.current + 90.days }

    before do
      service.instance_variable_set(:@cutoff_date, cutoff_date)
    end

    it 'returns false for empty array' do
      expect(service.send(:beyond_cutoff_date?, [])).to be false
    end

    it 'returns true when all releases are beyond cutoff' do
      releases_data = [
        { 'date' => (Date.current + 100.days).to_s },
        { 'date' => (Date.current + 120.days).to_s }
      ]
      expect(service.send(:beyond_cutoff_date?, releases_data)).to be true
    end

    it 'returns false when some releases are within cutoff' do
      releases_data = [
        { 'date' => (Date.current + 30.days).to_s },
        { 'date' => (Date.current + 100.days).to_s }
      ]
      expect(service.send(:beyond_cutoff_date?, releases_data)).to be false
    end
  end
end
