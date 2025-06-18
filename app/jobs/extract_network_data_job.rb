class ExtractNetworkDataJob < ApplicationJob
  queue_as :default

  def perform(network_id)
    network = Network.find_by(external_id: network_id)
    return unless network

    network_data = Crawl4aiService.extract_network(network_id)
    return if network_data.blank?

    # Handle country
    country = if network_data["country_code"].present?
                Country.find_or_create_by_shortcode(network_data["country_code"])
    else
                nil
    end

    network.update!(
      name: network_data["name"].presence || network.name,
      description: network_data["description"],
      time_zone: network_data["time_zone"],
      official_site_url: network_data["official_url"],
      country: country
    )
  rescue => e
    Rails.logger.error "[ExtractNetworkDataJob] Error extracting network data for network_id #{network_id}: #{e.message}"
  end
end
