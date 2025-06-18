require "spec_helper"
require_relative "../../app/services/crawl4ai_service"

RSpec.describe Crawl4aiService, type: :service do
  describe ".extract" do
    let(:url)   { "https://example.com/page" }
    let(:json_answer) do
      <<~JSON
        ```json
        [
          {
            "date": "2025-06-17",
            "time": "22:00",
            "episode_id": 12345,
            "network_id": 67890,
            "show_id": 54321
          }
        ]
        ```
      JSON
    end

    let(:mock_response) do
      instance_double(HTTParty::Response,
                      code: 200,
                      body: { answer: json_answer }.to_json,
                      success?: true)
    end

    before do
      allow(HTTParty).to receive(:get).and_return(mock_response)
    end

    it "returns parsed JSON array of releases" do
      result = described_class.extract(url)
      expect(result).to be_an(Array)
      expect(result.first).to include(
        "date" => "2025-06-17",
        "time" => "22:00",
        "episode_id" => 12345,
        "network_id" => 67890,
        "show_id" => 54321
      )
    end
  end

  describe ".extract_show" do
    let(:show_id) { 123 }
    let(:json_answer) do
      <<~JSON
        ```json
        {
          "title": "Game of Thrones",
          "description": "Epic fantasy series",
          "show_type": "Drama",
          "official_site_url": "https://hbo.com/got",
          "genres": ["Fantasy", "Drama"],
          "vote": 9.2
        }
        ```
      JSON
    end

    let(:mock_response) do
      instance_double(HTTParty::Response,
                      code: 200,
                      body: { answer: json_answer }.to_json,
                      success?: true)
    end

    before do
      allow(HTTParty).to receive(:get).and_return(mock_response)
    end

    it "returns parsed JSON object with show data" do
      result = described_class.extract_show(show_id)
      expect(result).to be_a(Hash)
      expect(result).to include(
        "title" => "Game of Thrones",
        "description" => "Epic fantasy series",
        "show_type" => "Drama",
        "official_site_url" => "https://hbo.com/got",
        "genres" => [ "Fantasy", "Drama" ],
        "vote" => 9.2
      )
    end

    it "calls the correct URL" do
      expect(HTTParty).to receive(:get).with(
        a_string_matching(/tvmaze\.com%2Fshows%2F123/),
        any_args
      ).and_return(mock_response)

      described_class.extract_show(show_id)
    end
  end

  describe ".extract_episode" do
    let(:episode_id) { 456 }
    let(:json_answer) do
      <<~JSON
        ```json
        {
          "season": 1,
          "episode": 5,
          "airdate": "2025-06-15",
          "runtime": 60,
          "summary": "An epic episode"
        }
        ```
      JSON
    end

    let(:mock_response) do
      instance_double(HTTParty::Response,
                      code: 200,
                      body: { answer: json_answer }.to_json,
                      success?: true)
    end

    before do
      allow(HTTParty).to receive(:get).and_return(mock_response)
    end

    it "returns parsed JSON object with episode data" do
      result = described_class.extract_episode(episode_id)
      expect(result).to be_a(Hash)
      expect(result).to include(
        "season" => 1,
        "episode" => 5,
        "airdate" => "2025-06-15",
        "runtime" => 60,
        "summary" => "An epic episode"
      )
    end

    it "calls the correct URL" do
      expect(HTTParty).to receive(:get).with(
        a_string_matching(/tvmaze\.com%2Fepisodes%2F456/),
        any_args
      ).and_return(mock_response)

      described_class.extract_episode(episode_id)
    end
  end
end
