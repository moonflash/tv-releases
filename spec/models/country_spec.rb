require 'rails_helper'

RSpec.describe Country, type: :model do
  describe 'validations' do
    subject { build(:country) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:shortcode) }
    it { should validate_uniqueness_of(:shortcode).case_insensitive }
  end

  describe 'associations' do
    it { should have_many(:networks).dependent(:destroy) }

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
    let(:country) { create(:country, name: 'United States', shortcode: 'US') }

    it 'finds existing country by shortcode' do
      country # ensure it exists before method call
      expect(described_class.find_or_create_by_shortcode('US')).to eq(country)
    end

    it 'creates new country when none exists' do
      expect { described_class.find_or_create_by_shortcode('CA') }.to change(Country, :count).by(1)
    end

    it 'normalizes shortcode to uppercase' do
      new_country = described_class.find_or_create_by_shortcode('ca')
      expect(new_country.shortcode).to eq('CA')
    end
  end
end
