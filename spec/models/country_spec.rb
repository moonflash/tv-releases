require 'rails_helper'

RSpec.describe Country, type: :model do
  describe 'validations' do
    it 'validates presence of name' do
      country = Country.new(shortcode: 'US')
      expect(country).not_to be_valid
      expect(country.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of shortcode' do
      country = Country.new(name: 'United States')
      expect(country).not_to be_valid
      expect(country.errors[:shortcode]).to include("can't be blank")
    end

    it 'validates uniqueness of shortcode' do
      Country.create!(name: 'United States', shortcode: 'US')
      country = Country.new(name: 'USA', shortcode: 'US')
      expect(country).not_to be_valid
      expect(country.errors[:shortcode]).to include("has already been taken")
    end
  end

  describe 'associations' do
    it 'has many networks' do
      association = Country.reflect_on_association(:networks)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:nullify)
    end

    it 'has many shows through networks' do
      association = Country.reflect_on_association(:shows)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:networks)
    end

    it 'has many episodes through shows' do
      association = Country.reflect_on_association(:episodes)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:shows)
    end

    it 'has many releases through episodes' do
      association = Country.reflect_on_association(:releases)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:episodes)
    end
  end

  describe '.find_or_create_by_shortcode' do
    context 'when shortcode is blank' do
      it 'returns nil' do
        expect(Country.find_or_create_by_shortcode('')).to be_nil
        expect(Country.find_or_create_by_shortcode(nil)).to be_nil
      end
    end

    context 'when country exists' do
      let!(:existing_country) { Country.create!(name: 'United States', shortcode: 'US') }

      it 'returns existing country' do
        result = Country.find_or_create_by_shortcode('us')
        expect(result).to eq(existing_country)
      end

      it 'normalizes shortcode to uppercase' do
        result = Country.find_or_create_by_shortcode('us')
        expect(result.shortcode).to eq('US')
      end
    end

    context 'when country does not exist' do
      it 'creates new country with provided name' do
        result = Country.find_or_create_by_shortcode('CA', 'Canada')
        expect(result.shortcode).to eq('CA')
        expect(result.name).to eq('Canada')
        expect(result).to be_persisted
      end

      it 'creates new country with shortcode as name when name not provided' do
        result = Country.find_or_create_by_shortcode('DE')
        expect(result.shortcode).to eq('DE')
        expect(result.name).to eq('DE')
        expect(result).to be_persisted
      end
    end
  end
end
