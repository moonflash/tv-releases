# Shared mock configuration for Crawl4aiService to prevent actual HTTP requests during testing
require 'webmock/rspec'

RSpec.configure do |config|
  config.before(:each) do
    # Block all real HTTP requests
    WebMock.disable_net_connect!

    # Stub the crawler endpoint
    WebMock.stub_request(:get, /http:\/\/crawler:11235\/llm\//)
      .to_return(
        status: 200,
        body: '{"answer": "```json\n{}\n```"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    # Stub TVMaze show endpoints
    WebMock.stub_request(:get, /https:\/\/www\.tvmaze\.com\/shows\/\d+/)
      .to_return(
        status: 200,
        body: '{"answer": "```json\n{}\n```"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    # Stub TVMaze episode endpoints
    WebMock.stub_request(:get, /https:\/\/www\.tvmaze\.com\/episodes\/\d+/)
      .to_return(
        status: 200,
        body: '{"answer": "```json\n{}\n```"}',
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock awesome_print to prevent debug output during tests
    # Try multiple approaches to catch the ap method
    allow(Kernel).to receive(:ap)
    allow(MAIN).to receive(:ap) if defined?(MAIN)
    allow_any_instance_of(Object).to receive(:ap)

    # Also try stubbing it globally
    if defined?(::AwesomePrint)
      allow(::AwesomePrint).to receive(:ap)
    end

    # Provide default stubs for service methods so any unmocked call does not hit external services
    allow(Crawl4aiService).to receive(:extract).and_return([])
    allow(Crawl4aiService).to receive(:extract_show).and_return({})
    allow(Crawl4aiService).to receive(:extract_episode).and_return({})
  end

  config.after(:each) do
    # Reset WebMock after each test
    WebMock.reset!
  end
end
