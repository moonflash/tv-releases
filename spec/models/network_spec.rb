require 'rails_helper'

RSpec.describe Network, type: :model do
  let(:country) { Country.create!(name: 'United States', shortcode: 'US') }

  describe 'validations' do
    it 'validates presence of name' do
      network = Network.new
      network.valid?
      expect(network.errors[:name]).to include("can't be blank")
    end

    it 'validates uniqueness of name (case insensitive)' do
      Network.create!(name: 'HBO', external_id: 'hbo_123', country: country)
      duplicate = Network.new(name: 'hbo', external_id: 'hbo_456', country: country)
      duplicate.valid?
      expect(duplicate.errors[:name]).to include('has already been taken')
    end

    it 'validates presence of external_id' do
      network = Network.new(name: 'HBO', country: country)
      network.valid?
      expect(network.errors[:external_id]).to include("can't be blank")
    end

    it 'validates uniqueness of external_id' do
      Network.create!(name: 'HBO', external_id: 'hbo_123', country: country)
      duplicate = Network.new(name: 'HBO Max', external_id: 'hbo_123', country: country)
      duplicate.valid?
      expect(duplicate.errors[:external_id]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it 'belongs to country' do
      network = Network.new
      expect(network).to respond_to(:country)
    end

    it 'has many shows' do
      network = Network.new
      expect(network).to respond_to(:shows)
    end

    it 'has many episodes through shows' do
      network = Network.new
      expect(network).to respond_to(:episodes)
    end

    it 'has many releases through episodes' do
      network = Network.new
      expect(network).to respond_to(:releases)
    end
  end

  describe '.find_or_create_by_fuzzy_name_and_external_id' do
    it 'finds existing network by external_id' do
      existing = Network.create!(name: 'HBO', external_id: 'hbo_123', country: country)
      result = Network.find_or_create_by_fuzzy_name_and_external_id('Home Box Office', 'hbo_123', country)
      expect(result).to eq(existing)
    end

    it 'creates new network when none exists' do
      expect {
        Network.find_or_create_by_fuzzy_name_and_external_id('HBO', 'hbo_123', country)
      }.to change(Network, :count).by(1)
    end

    it 'returns nil when network_name is blank' do
      result = Network.find_or_create_by_fuzzy_name_and_external_id('', 'hbo_123', country)
      expect(result).to be_nil
    end

    it 'returns nil when external_id is blank' do
      result = Network.find_or_create_by_fuzzy_name_and_external_id('HBO', '', country)
      expect(result).to be_nil
    end

    it 'finds existing network by fuzzy name matching' do
      existing = Network.create!(name: 'HBO', external_id: 'hbo_123', country: country)
      result = Network.find_or_create_by_fuzzy_name_and_external_id('HBO Network', 'hbo_456', country)
      expect(result).to eq(existing)
      expect(result.external_id).to eq('hbo_456') # Should update external_id
    end
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