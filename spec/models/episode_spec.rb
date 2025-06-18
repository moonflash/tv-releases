require 'rails_helper'

RSpec.describe Episode, type: :model do
  let(:country) { Country.create!(name: 'United States', shortcode: 'US') }
  let(:network) { Network.create!(name: 'HBO', external_id: 'hbo_123', country: country) }
  let(:show) { Show.create!(title: 'Game of Thrones', external_id: 'show_123', network: network) }

  describe 'validations' do
    subject { build(:episode) }
    it { should validate_presence_of(:external_id) }
    it { should validate_uniqueness_of(:external_id) }
    it { should validate_presence_of(:season_number).on(:update) }
    it { should validate_presence_of(:episode_number).on(:update) }
    it { should validate_uniqueness_of(:season_number).scoped_to(:show_id).on(:update) }
    it { should validate_uniqueness_of(:episode_number).scoped_to(:show_id).on(:update) }
  end

  describe 'associations' do
    it { should belong_to(:show) }
    it { should have_many(:releases).dependent(:destroy) }
  end

  describe '.find_or_create_from_external_id' do
    let(:episode_data) do
      {
        'season' => 1,
        'episode' => 1,
        'summary' => 'Test Episode'
      }
    end

    before do
      allow(Crawl4aiService).to receive(:extract_episode).and_return(episode_data)
    end

    it 'finds existing episode by external_id' do
      episode = create(:episode, external_id: '123', show: show)
      found = described_class.find_or_create_from_external_id('123', show)
      expect(found).to eq(episode)
    end

    it 'creates new episode when none exists' do
      expect {
        described_class.find_or_create_from_external_id('123', show)
      }.to change(Episode, :count).by(1)
    end

    it 'creates episode with correct attributes' do
      episode = described_class.find_or_create_from_external_id('123', show)
      expect(episode.external_id).to eq('123')
      expect(episode.show).to eq(show)
    end

    it 'returns nil when external_id is blank' do
      expect(described_class.find_or_create_from_external_id(nil, show)).to be_nil
    end

    it 'handles service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_episode).and_raise(StandardError)
      expect {
        result = described_class.find_or_create_from_external_id('123', show)
        expect(result).to be_a(Episode)
      }.not_to raise_error
    end
  end

  describe '#title' do
    let(:episode) { build(:episode) }

    it 'returns TBD for new episodes' do
      episode.season_number = 0
      episode.episode_number = 0
      expect(episode.title).to eq('TBD')
    end

    it 'returns formatted title for complete episodes' do
      episode.season_number = 1
      episode.episode_number = 2
      expect(episode.title).to eq('S01E02')
    end
  end
end
