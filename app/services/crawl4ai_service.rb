require "httparty"
require "json"
require "awesome_print"
require "uri"

class Crawl4aiService
  include HTTParty

  def self.extract(url)
    instruction = <<~INSTRUCTION
      Read the the contend of th url very carefully.
      There will be at least 18 releases on the page and you should recognize them all.
      Be aware that date-time will look like this: Jun 16, 2025 at 22:00.
      There will also be announcements for each releases with sometning like "In 7 hours" or "In a day" that you should ignore.
      Extract show_id, episode_id, and network_id from the approproate urls.

      Return the list of releases and extract values using the following JSON schema:

     schema: {
        type:  "array",
        minItems: 18,
        maxItems: 20,
        items: {
          type: "object",
          properties: {
            date:       { type: "string", format: "date", pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" },
            time:       { type: "string", format: "time", pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$" },
            episode_id: { type: "integer" },
            network_id: { type: "integer" },
            show_id: { type: "integer" }
          }
        }
      }
    INSTRUCTION

    encoded_url         = URI.encode_www_form_component(url)
    encoded_instruction = URI.encode_www_form_component(instruction.strip)

    endpoint = "http://crawler:11235/llm/#{encoded_url}?q=#{encoded_instruction}"

    response = HTTParty.get(endpoint,
                            headers: { "Content-Type" => "application/json" },
                            timeout: 300)

    ap "[Crawl4aiService] HTTP #{response.code} (#{response.body.bytesize} bytes)"

    # Log the response body for debugging HTTP 500 errors
    unless response.success?
      ap "[Crawl4aiService] Error response body: #{response.body}"
      ap "[Crawl4aiService] Request URL length: #{endpoint.length} characters"
      return []
    end

    raw_payload = JSON.parse(response.body)

    # LLM returns a JSON object with an "answer" key whose value is a markdown-fenced
    # JSON string.  Remove the fence (```json ... ```) and parse the inner JSON so
    # callers get Ruby objects directly.
    answer_markdown = raw_payload["answer"]
    return [] unless answer_markdown.is_a?(String)

    # Strip starting ```json and ending ```
    json_str = answer_markdown
                .sub(/^```json\s*/i, "")
                .sub(/```\s*$/i, "")

    parsed = JSON.parse(json_str)
    parsed
  rescue => e
    ap "Exception while calling local LLM endpoint: #{e.message}"
    []
  end

  def self.extract_show(show_id)
    url = "https://www.tvmaze.com/shows/#{show_id}"

    instruction = <<~INSTRUCTION
      Extract show information from the TVMaze show page.
      Return the show data using the following JSON schema:

      schema: {
        type: "object",
        properties: {
          title: { type: "string" },
          description: { type: "string" },
          show_type: { type: "string" },
          official_site_url: { type: "string" },
          genres: { type: "array", items: { type: "string" } },
          vote: { type: "number", minimum: 0, maximum: 10 }
        },
        required: ["title"]
      }
    INSTRUCTION

    make_crawl_request(url, instruction)
  rescue => e
    ap "Exception while extracting show #{show_id}: #{e.message}"
    {}
  end

  def self.extract_episode(episode_id)
    url = "https://www.tvmaze.com/episodes/#{episode_id}"

    instruction = <<~INSTRUCTION
      Extract episode information from the TVMaze episode page.
      Return the episode data using the following JSON schema:

      schema: {
        type: "object",
        properties: {
          season: { type: "integer" },
          episode: { type: "integer" },
          airdate: { type: "string", format: "date" },
          runtime: { type: "integer" },
          summary: { type: "string" }
        },
        required: ["season", "episode"]
      }
    INSTRUCTION

    make_crawl_request(url, instruction)
  rescue => e
    ap "Exception while extracting episode #{episode_id}: #{e.message}"
    {}
  end

  def self.extract_network(network_id)
    url = "https://www.tvmaze.com/networks/#{network_id}"

    instruction = <<~INSTRUCTION
      Extract network information from the TVMaze network page.
      Return the network data using the following JSON schema:

      schema: {
        type: "object",
        properties: {
          name: { type: "string" },
          country_code: { type: "string", pattern: "^[A-Z]{2}$" },
          time_zone: { type: "string" },
          official_url: { type: "string" },
          description: { type: "string" }
        },
        required: ["name"]
      }
    INSTRUCTION

    make_crawl_request(url, instruction)
  rescue => e
    ap "Exception while extracting network #{network_id}: #{e.message}"
    {}
  end

  private

  def self.make_crawl_request(url, instruction)
    encoded_url         = URI.encode_www_form_component(url)
    encoded_instruction = URI.encode_www_form_component(instruction.strip)

    endpoint = "http://crawler:11235/llm/#{encoded_url}?q=#{encoded_instruction}"

    response = HTTParty.get(endpoint,
                            headers: { "Content-Type" => "application/json" },
                            timeout: 300)

    ap "[Crawl4aiService] HTTP #{response.code} (#{response.body.bytesize} bytes) for #{url}"

    unless response.success?
      ap "[Crawl4aiService] Error response body: #{response.body}"
      return {}
    end

    raw_payload = JSON.parse(response.body)
    answer_markdown = raw_payload["answer"]
    return {} unless answer_markdown.is_a?(String)

    # Strip starting ```json and ending ```
    json_str = answer_markdown
                .sub(/^```json\s*/i, "")
                .sub(/```\s*$/i, "")

    JSON.parse(json_str)
  end
end
