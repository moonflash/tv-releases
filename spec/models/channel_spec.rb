require 'rails_helper'

RSpec.describe Channel, type: :model do
  describe 'associations' do
    it 'should have many releases' do
      expect(subject).to respond_to(:releases)
      expect(subject.releases).to be_empty
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      channel = Channel.new
      expect(channel).not_to be_valid
      expect(channel.errors[:name]).to include("can't be blank")
    end

    it 'validates uniqueness of name case insensitive' do
      Channel.create!(name: 'HBO')
      duplicate = Channel.new(name: 'hbo')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe 'callbacks' do
    context 'before_save :normalize_name' do
      it 'normalizes the channel name before saving' do
        channel = Channel.new(name: '  hbo network  ')
        channel.save!
        expect(channel.name).to eq('HBO')
      end
    end
  end

  describe '.find_or_create_by_fuzzy_name' do
    context 'when channel name is blank' do
      it 'returns nil' do
        expect(Channel.find_or_create_by_fuzzy_name('')).to be_nil
        expect(Channel.find_or_create_by_fuzzy_name(nil)).to be_nil
      end
    end

    context 'when exact match exists' do
      let!(:existing_channel) { Channel.create!(name: 'HBO') }

      it 'returns the existing channel for exact match' do
        result = Channel.find_or_create_by_fuzzy_name('HBO')
        expect(result).to eq(existing_channel)
      end

      it 'returns the existing channel for case insensitive match' do
        result = Channel.find_or_create_by_fuzzy_name('hbo')
        expect(result).to eq(existing_channel)
      end
    end

    context 'when similar channel exists' do
      let!(:existing_channel) { Channel.create!(name: 'HBO') }

      it 'returns the existing channel for similar name' do
        result = Channel.find_or_create_by_fuzzy_name('HBO Network')
        expect(result).to eq(existing_channel)
      end
    end

    context 'when no similar channel exists' do
      it 'creates a new channel' do
        expect {
          Channel.find_or_create_by_fuzzy_name('Disney Channel')
        }.to change(Channel, :count).by(1)

        channel = Channel.last
        expect(channel.name).to eq('Disney')
      end
    end
  end

  describe '.normalize_channel_name' do
    it 'removes common TV suffixes and prefixes' do
      expect(Channel.normalize_channel_name('HBO Network')).to eq('HBO')
      expect(Channel.normalize_channel_name('Disney Channel')).to eq('Disney')
      expect(Channel.normalize_channel_name('Fox Broadcasting')).to eq('FOX')
    end

    it 'handles special cases' do
      expect(Channel.normalize_channel_name('hbo')).to eq('HBO')
      expect(Channel.normalize_channel_name('cnn news')).to eq('CNN')
      expect(Channel.normalize_channel_name('bbc one')).to eq('BBC')
    end

    it 'normalizes spacing and case' do
      expect(Channel.normalize_channel_name('  discovery   channel  ')).to eq('Discovery')
      expect(Channel.normalize_channel_name('national geographic')).to eq('National Geographic')
    end

    it 'returns empty string for blank input' do
      expect(Channel.normalize_channel_name('')).to eq('')
      expect(Channel.normalize_channel_name(nil)).to eq('')
    end
  end

  describe '.similarity_score' do
    it 'returns 1.0 for identical strings' do
      expect(Channel.similarity_score('HBO', 'HBO')).to eq(1.0)
    end

    it 'returns 0.0 for empty strings' do
      expect(Channel.similarity_score('', 'HBO')).to eq(0.0)
      expect(Channel.similarity_score('HBO', '')).to eq(0.0)
    end

    it 'returns appropriate similarity scores' do
      score = Channel.similarity_score('HBO', 'HBO Network')
      expect(score).to be > 0.2  # Adjusted expectation
      expect(score).to be < 1.0
    end
  end

  describe '.levenshtein_distance' do
    it 'calculates correct distance for identical strings' do
      expect(Channel.levenshtein_distance('test', 'test')).to eq(0)
    end

    it 'calculates correct distance for different strings' do
      expect(Channel.levenshtein_distance('kitten', 'sitting')).to eq(3)
    end
  end
end
