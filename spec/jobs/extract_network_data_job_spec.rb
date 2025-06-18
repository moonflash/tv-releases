require 'rails_helper'

RSpec.describe ExtractNetworkDataJob, type: :job do
  include ActiveJob::TestHelper

  let(:network) { create(:network, external_id: '123', name: 'Placeholder', country: nil) }

  context 'with valid payload' do
    let(:payload) do
      {
        'name' => 'HBO New',
        'country_code' => 'US',
        'time_zone' => 'America/New_York',
        'official_url' => 'https://www.hbo.com',
        'description' => 'Premium cable and streaming service'
      }
    end

    before do
      network # ensure creation
      allow(Crawl4aiService).to receive(:extract_network).with('123').and_return(payload)
    end

    it 'updates network attributes and creates country' do
      perform_enqueued_jobs { described_class.perform_later('123') }

      network.reload
      expect(network.name).to eq(Network.normalize_network_name('HBO New'))
      expect(network.description).to eq('Premium cable and streaming service')
      expect(network.time_zone).to eq('America/New_York')
      expect(network.official_site_url).to eq('https://www.hbo.com')
      expect(network.country).not_to be_nil
      expect(network.country.shortcode).to eq('US')
    end
  end

  context 'when service returns blank data' do
    before do
      network
      allow(Crawl4aiService).to receive(:extract_network).with('123').and_return({})
    end

    it 'does not change the network' do
      expect {
        perform_enqueued_jobs { described_class.perform_later('123') }
      }.not_to change { network.reload.updated_at }
    end
  end
end
