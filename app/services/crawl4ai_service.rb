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
      Episode number and season number will look like 8x01 (8 is episode, season is 1)
      Return the list of releases and extract values using the following JSON schema:

     schema: {
        type:  "array",
        minItems: 18,
        maxItems: 20,
        items: {
          type: "object",
          properties: {
            date:   { type: "string", format: "date", pattern: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" },
            time:   { type: "string", format: "time", pattern: "^([01][0-9]|2[0-3]):[0-5][0-9]$" },
            title:  { type: "string" },
            channel: { type: "string" }
            episode: {
              type: "object",
              properties: {
                number: { type: "number" },
                season: { type: "number" },
                title: {  type: "string" }
              }
            }
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

    return [] unless response.success?

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
end
