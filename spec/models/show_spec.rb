require 'rails_helper'

RSpec.describe Show, type: :model do
  describe 'validations' do
    subject { build(:show) }
    it { should validate_presence_of(:external_id) }
    it { should validate_uniqueness_of(:external_id) }
    it { should validate_presence_of(:title).on(:update) }
  end

  describe 'associations' do
    it { should belong_to(:network) }
    it { should have_many(:episodes).dependent(:destroy) }
    it { should have_many(:releases).through(:episodes) }
  end

  describe '.find_or_create_from_external_id' do
    let(:network) { create(:network) }
    let(:show) { create(:show, external_id: '123', network: network) }

    it 'finds existing show by external_id' do
      show
      expect(described_class.find_or_create_from_external_id('123', network)).to eq(show)
    end

    it 'creates new show when none exists' do
      expect { described_class.find_or_create_from_external_id('456', network) }.to change(Show, :count).by(1)
    end

    it 'creates show with correct attributes' do
      new_show = described_class.find_or_create_from_external_id('456', network)
      expect(new_show.external_id).to eq('456')
      expect(new_show.network).to eq(network)
    end

    it 'returns nil when external_id is blank' do
      expect(described_class.find_or_create_from_external_id('', network)).to be_nil
    end

    it 'returns the show even when show data is blank (as async data will populate later)' do
      allow(Crawl4aiService).to receive(:extract_show).and_return({})
      result = described_class.find_or_create_from_external_id('123', network)
      expect(result).to be_a(Show)
    end

    it 'still creates show when title is missing from show data (title will be populated later)' do
      allow(Crawl4aiService).to receive(:extract_show).and_return({ description: 'Test' })
      result = described_class.find_or_create_from_external_id('123', network)
      expect(result).to be_a(Show)
    end

    it 'handles service exceptions gracefully' do
      allow(Crawl4aiService).to receive(:extract_show).and_raise(StandardError)
      expect {
        described_class.find_or_create_from_external_id('123', network)
      }.not_to raise_error
    end
  end
end 