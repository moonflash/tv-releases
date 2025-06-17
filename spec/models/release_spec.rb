require 'rails_helper'

RSpec.describe Release, type: :model do
  describe 'associations' do
    it 'should belong to channel optionally' do
      expect(subject).to respond_to(:channel)
      expect(subject.channel).to be_nil
    end
  end

  describe 'validations' do
    it 'validates presence of required fields' do
      release = Release.new
      expect(release).not_to be_valid
      expect(release.errors[:air_date]).to include("can't be blank")
      expect(release.errors[:air_time]).to include("can't be blank")
      expect(release.errors[:title]).to include("can't be blank")
      expect(release.errors[:season_number]).to include("can't be blank")
      expect(release.errors[:episode_number]).to include("can't be blank")
      expect(release.errors[:episode_title]).to include("can't be blank")
    end

    context 'uniqueness validation' do
      let!(:existing_release) do
        Release.create!(
          title: 'Game of Thrones',
          air_date: Date.parse('2024-01-15'),
          air_time: '21:00:00',
          season_number: 8,
          episode_number: 1,
          episode_title: 'The Last Watch'
        )
      end

      it 'validates uniqueness of title scoped to air_date, air_time, season_number, and episode_number' do
        duplicate_release = Release.new(
          title: 'Game of Thrones',
          air_date: Date.parse('2024-01-15'),
          air_time: '21:00:00',
          season_number: 8,
          episode_number: 1,
          episode_title: 'Different Title'
        )

        expect(duplicate_release).not_to be_valid
        expect(duplicate_release.errors[:title]).to include('Release already exists with same title, air date, time, season and episode number')
      end

      it 'allows same title with different air_date' do
        different_release = Release.new(
          title: 'Game of Thrones',
          air_date: Date.parse('2024-01-16'),
          air_time: '21:00:00',
          season_number: 8,
          episode_number: 1,
          episode_title: 'The Last Watch'
        )

        expect(different_release).to be_valid
      end
    end
  end

  describe 'scopes' do
    let!(:past_release) do
      Release.create!(
        title: 'Past Show',
        air_date: Date.yesterday,
        air_time: '20:00:00',
        season_number: 1,
        episode_number: 1,
        episode_title: 'Pilot'
      )
    end

    let!(:upcoming_release) do
      Release.create!(
        title: 'Future Show',
        air_date: Date.tomorrow,
        air_time: '21:00:00',
        season_number: 1,
        episode_number: 1,
        episode_title: 'Pilot'
      )
    end

    describe '.upcoming' do
      it 'returns only releases with air_date >= today' do
        expect(Release.upcoming).to include(upcoming_release)
        expect(Release.upcoming).not_to include(past_release)
      end
    end

    describe '.within_days' do
      it 'returns releases within specified days from today' do
        expect(Release.within_days(7)).to include(upcoming_release)
        expect(Release.within_days(0)).not_to include(upcoming_release)
      end
    end
  end

  describe '.find_or_create_from_crawl_data' do
    let(:channel) { Channel.create!(name: 'HBO') }
    let(:crawl_data) do
      {
        'title' => 'Game of Thrones',
        'date' => '2024-01-15',
        'time' => '21:00',
        'episode' => {
          'season' => 8,
          'number' => 1,
          'title' => 'The Last Watch'
        }
      }
    end

    context 'when release does not exist' do
      it 'creates a new release' do
        expect {
          Release.find_or_create_from_crawl_data(crawl_data, channel)
        }.to change(Release, :count).by(1)

        release = Release.last
        expect(release.title).to eq('Game of Thrones')
        expect(release.air_date).to eq(Date.parse('2024-01-15'))
        expect(release.air_time.strftime('%H:%M:%S')).to eq('21:00:00')
        expect(release.season_number).to eq(8)
        expect(release.episode_number).to eq(1)
        expect(release.episode_title).to eq('The Last Watch')
        expect(release.channel).to eq(channel)
      end
    end

    context 'when release already exists' do
      let!(:existing_release) do
        Release.create!(
          title: 'Game of Thrones',
          air_date: Date.parse('2024-01-15'),
          air_time: '21:00:00',
          season_number: 8,
          episode_number: 1,
          episode_title: 'The Last Watch'
        )
      end

      it 'returns the existing release without creating a new one' do
        expect {
          result = Release.find_or_create_from_crawl_data(crawl_data, channel)
          expect(result).to eq(existing_release)
        }.not_to change(Release, :count)
      end
    end

    context 'with invalid data' do
      it 'handles invalid date format' do
        invalid_data = crawl_data.merge('date' => 'invalid-date')

        expect {
          Release.find_or_create_from_crawl_data(invalid_data, channel)
        }.to raise_error(Date::Error)
      end

      it 'handles invalid time format' do
        invalid_data = crawl_data.merge('time' => 'invalid-time')

        expect {
          Release.find_or_create_from_crawl_data(invalid_data, channel)
        }.to raise_error(ArgumentError)
      end
    end
  end
end
