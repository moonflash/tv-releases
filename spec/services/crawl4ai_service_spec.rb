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
            "title": "Some Show",
            "channel": "ABC",
            "episode": {
              "number": 1,
              "season": 8,
              "title": "Premiere"
            }
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
        "title" => "Some Show",
        "channel" => "ABC"
      )
    end
  end
end
