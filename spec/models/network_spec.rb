require 'rails_helper'

RSpec.describe Network, type: :model do
  describe 'validations' do
    subject { build(:network) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should validate_presence_of(:external_id) }
    it { should validate_uniqueness_of(:external_id) }
  end

  describe 'associations' do
    it { should belong_to(:country).optional }
    it { should have_many(:shows).dependent(:destroy) }
  end

  describe '.normalize_network_name' do
    it 'removes common TV suffixes' do
      expect(Network.normalize_network_name('HBO TV')).to eq('HBO')
      expect(Network.normalize_network_name('CNN Network')).to eq('CNN')
      expect(Network.normalize_network_name('ABC Channel')).to eq('ABC')
    end

    it 'handles special cases' do
      expect(Network.normalize_network_name('hbo')).to eq('HBO')
      expect(Network.normalize_network_name('cnn')).to eq('CNN')
      expect(Network.normalize_network_name('bbc')).to eq('BBC')
      expect(Network.normalize_network_name('abc')).to eq('ABC')
    end

    it 'titleizes regular names' do
      expect(Network.normalize_network_name('discovery channel')).to eq('Discovery')
    end
  end
end
