require 'rails_helper'

RSpec.describe Release, type: :model do
  let(:channel) { Channel.create!(name: "Test Channel") }
  let(:country) { Country.create!(name: "United States", shortcode: "US") }

  describe 'associations' do
    it 'should belong to channel optionally' do
      association = Release.reflect_on_association(:channel)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be(true)
    end

    it 'should belong to country optionally' do
      association = Release.reflect_on_association(:country)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be(true)
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

    it 'validates uniqueness of external_id when present' do
      Release.create!(
        air_date: Date.today,
        air_time: '21:00',
        title: 'Test Show',
        season_number: 1,
        episode_number: 1,
        episode_title: 'Pilot',
        external_id: 'test123',
        channel: channel
      )

      duplicate = Release.new(
        air_date: Date.today + 1,
        air_time: '22:00',
        title: 'Different Show',
        season_number: 2,
        episode_number: 2,
        episode_title: 'Different Episode',
        external_id: 'test123',
        channel: channel
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:external_id]).to include("has already been taken")
    end

    it 'allows blank external_id' do
      release = Release.new(
        air_date: Date.today,
        air_time: '21:00',
        title: 'Test Show',
        season_number: 1,
        episode_number: 1,
        episode_title: 'Pilot',
        external_id: '',
        channel: channel
      )

      expect(release).to be_valid
    end

    describe 'uniqueness validation' do
      it 'validates uniqueness of title scoped to air_date, air_time, season_number, and episode_number' do
        Release.create!(
          air_date: Date.today,
          air_time: '21:00',
          title: 'Test Show',
          season_number: 1,
          episode_number: 1,
          episode_title: 'Pilot',
          channel: channel
        )

        duplicate = Release.new(
          air_date: Date.today,
          air_time: '21:00',
          title: 'Test Show',
          season_number: 1,
          episode_number: 1,
          episode_title: 'Different Episode Title',
          channel: channel
        )

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:title]).to include("Release already exists with same title, air date, time, season and episode number")
      end

      it 'allows same title with different air_date' do
        Release.create!(
          air_date: Date.today,
          air_time: '21:00',
          title: 'Test Show',
          season_number: 1,
          episode_number: 1,
          episode_title: 'Pilot',
          channel: channel
        )

        different_date = Release.new(
          air_date: Date.today + 1,
          air_time: '21:00',
          title: 'Test Show',
          season_number: 1,
          episode_number: 1,
          episode_title: 'Pilot',
          channel: channel
        )

        expect(different_date).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @past_release = Release.create!(
        air_date: Date.yesterday,
        air_time: '21:00',
        title: 'Past Show',
        season_number: 1,
        episode_number: 1,
        episode_title: 'Past Episode',
        channel: channel
      )

      @today_release = Release.create!(
        air_date: Date.today,
        air_time: '21:00',
        title: 'Today Show',
        season_number: 1,
        episode_number: 1,
        episode_title: 'Today Episode',
        channel: channel
      )

      @future_release = Release.create!(
        air_date: Date.today + 5,
        air_time: '21:00',
        title: 'Future Show',
        season_number: 1,
        episode_number: 1,
        episode_title: 'Future Episode',
        channel: channel
      )
    end

    describe '.upcoming' do
      it 'returns only releases with air_date >= today' do
        upcoming = Release.upcoming
        expect(upcoming).to include(@today_release, @future_release)
        expect(upcoming).not_to include(@past_release)
      end
    end

    describe '.within_days' do
      it 'returns releases within specified days from today' do
        within_3_days = Release.within_days(3)
        expect(within_3_days).to include(@today_release)
        expect(within_3_days).not_to include(@future_release, @past_release)
      end
    end
  end

  describe '.find_or_create_from_crawl_data' do
    let(:crawl_data) do
      {
        "date" => "2025-06-17",
        "time" => "21:00",
        "title" => "Test Show",
        "url" => "https://example.com/show/123",
        "external_id" => "ext123",
        "country" => "United States",
        "country_code" => "US",
        "episode" => {
          "season" => 1,
          "number" => 1,
          "title" => "Pilot Episode"
        }
      }
    end

    context 'when release does not exist' do
      it 'creates a new release with all fields including country' do
        expect {
          Release.find_or_create_from_crawl_data(crawl_data, channel)
        }.to change(Release, :count).by(1).and change(Country, :count).by(1)

        release = Release.last
        expect(release.title).to eq("Test Show")
        expect(release.air_date).to eq(Date.parse("2025-06-17"))
        expect(release.air_time.strftime("%H:%M:%S")).to eq("21:00:00")
        expect(release.season_number).to eq(1)
        expect(release.episode_number).to eq(1)
        expect(release.episode_title).to eq("Pilot Episode")
        expect(release.url).to eq("https://example.com/show/123")
        expect(release.external_id).to eq("ext123")
        expect(release.channel).to eq(channel)
        expect(release.country.shortcode).to eq("US")
        expect(release.country.name).to eq("United States")
      end

      it 'creates a new release without country when country_code is not provided' do
        data_without_country = crawl_data.except("country", "country_code")

        expect {
          Release.find_or_create_from_crawl_data(data_without_country, channel)
        }.to change(Release, :count).by(1).and change(Country, :count).by(0)

        release = Release.last
        expect(release.country).to be_nil
      end

      it 'reuses existing country when country_code matches' do
        existing_country = Country.create!(name: "USA", shortcode: "US")

        expect {
          Release.find_or_create_from_crawl_data(crawl_data, channel)
        }.to change(Release, :count).by(1).and change(Country, :count).by(0)

        release = Release.last
        expect(release.country).to eq(existing_country)
      end
    end

    context 'when release exists by external_id' do
      it 'updates the existing release' do
        existing_release = Release.create!(
          air_date: Date.parse("2025-06-16"),
          air_time: '20:00',
          title: 'Old Title',
          season_number: 2,
          episode_number: 2,
          episode_title: 'Old Episode',
          external_id: 'ext123',
          channel: channel
        )

        expect {
          found_release = Release.find_or_create_from_crawl_data(crawl_data, channel)
          expect(found_release).to eq(existing_release)
        }.not_to change(Release, :count)

        existing_release.reload
        expect(existing_release.title).to eq("Test Show")
        expect(existing_release.air_date).to eq(Date.parse("2025-06-17"))
        expect(existing_release.url).to eq("https://example.com/show/123")
      end
    end

    context 'when release already exists by other fields' do
      it 'updates the existing release with new data' do
        existing_release = Release.create!(
          air_date: Date.parse("2025-06-17"),
          air_time: '21:00',
          title: 'Test Show',
          season_number: 1,
          episode_number: 1,
          episode_title: 'Old Episode Title',
          channel: channel
        )

        expect {
          found_release = Release.find_or_create_from_crawl_data(crawl_data, channel)
          expect(found_release).to eq(existing_release)
        }.not_to change(Release, :count)

        existing_release.reload
        expect(existing_release.episode_title).to eq("Pilot Episode")
        expect(existing_release.url).to eq("https://example.com/show/123")
        expect(existing_release.external_id).to eq("ext123")
      end
    end

    context 'with invalid data' do
      it 'handles invalid date format' do
        invalid_data = crawl_data.merge("date" => "invalid-date")
        expect {
          Release.find_or_create_from_crawl_data(invalid_data, channel)
        }.to raise_error(Date::Error)
      end

      it 'handles invalid time format' do
        invalid_data = crawl_data.merge("time" => "invalid-time")
        expect {
          Release.find_or_create_from_crawl_data(invalid_data, channel)
        }.to raise_error(ArgumentError)
      end
    end
  end
end
