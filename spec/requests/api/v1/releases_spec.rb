require 'rails_helper'

RSpec.describe "Api::V1::Releases", type: :request do
  describe "GET /api/v1/releases" do
    let(:path) { "/api/v1/releases" }

    context "without any filters" do
      it "returns releases ordered by air_date ascending" do
        older_release = create(:release, air_date: Date.today, air_time: '20:00')
        newer_release = create(:release, air_date: Date.today + 1.day, air_time: '20:00')

        get path

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["releases"].size).to eq(2)
        expect(json["releases"].first["id"]).to eq(older_release.id)
        expect(json["releases"].second["id"]).to eq(newer_release.id)
      end
    end

    context "with country filter" do
      it "returns releases only for the given country shortcode" do
        us_country = create(:country, shortcode: 'US')
        ca_country = create(:country, shortcode: 'CA')

        us_network = create(:network, country: us_country)
        ca_network = create(:network, country: ca_country)

        us_show = create(:show, network: us_network)
        ca_show = create(:show, network: ca_network)

        create(:release, episode: create(:episode, show: us_show))
        create(:release, episode: create(:episode, show: ca_show))

        get path, params: { country: 'US' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["releases"].size).to eq(1)
        expect(json["releases"].first.dig('episode', 'show', 'network', 'country', 'shortcode')).to eq('US')
      end
    end

    context "with network filter" do
      it "returns releases only for the given network id" do
        network_a = create(:network)
        network_b = create(:network)

        show_a = create(:show, network: network_a)
        show_b = create(:show, network: network_b)

        create(:release, episode: create(:episode, show: show_a))
        create(:release, episode: create(:episode, show: show_b))

        get path, params: { network: network_a.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["releases"].size).to eq(1)
        expect(json["releases"].first.dig('episode', 'show', 'network', 'id')).to eq(network_a.id)
      end
    end

    context "with date range filter" do
      it "returns releases only within the given air_date range" do
        in_range_release   = create(:release, air_date: Date.new(2025, 1, 15))
        before_range       = create(:release, air_date: Date.new(2025, 1,  1))
        after_range        = create(:release, air_date: Date.new(2025, 2,  1))

        get path, params: { start_date: '2025-01-10', end_date: '2025-01-20' }

        expect(response).to have_http_status(:ok)
        json_ids = JSON.parse(response.body).dig('releases').map { |h| h['id'] }
        expect(json_ids).to include(in_range_release.id)
        expect(json_ids).not_to include(before_range.id, after_range.id)
      end
    end

    context "with title search filter" do
      it "performs case-insensitive partial match on show title" do
        matching_show = create(:show, title: 'My Great Show')
        nonmatching_show = create(:show, title: 'Other Title')

        create(:release, episode: create(:episode, show: matching_show))
        create(:release, episode: create(:episode, show: nonmatching_show))

        get path, params: { q: 'great' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["releases"].size).to eq(1)
        expect(json["releases"].first.dig('episode', 'show', 'title')).to eq('My Great Show')
      end
    end

    context "with pagination params" do
      it "returns the correct slice of releases" do
        releases = create_list(:release, 3) do |release, i|
          release.update(air_date: Date.today + i.days)
        end

        get path, params: { per_page: 2, page: 2 }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["releases"].size).to eq(1)
        expect(json["releases"].first['id']).to eq(releases.third.id)
      end
    end
  end
end
