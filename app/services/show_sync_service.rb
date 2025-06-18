class ShowSyncService
  BATCH_SIZE = 100

  # Sync an individual show record with fresh data from Crawl4aiService.
  # Returns the updated show, :skipped if no data could be fetched.
  def self.sync(show)
    show_data = Crawl4aiService.extract_show(show.external_id)
    return :skipped if show_data.blank?

    ActiveRecord::Base.transaction do
      # Handle channel assignment – a show belongs to either a network OR a web-channel.
      if show_data["web_channel_id"].present?
        web_channel = WebChannel.find_or_create_by!(external_id: show_data["web_channel_id"]) do |wc|
          wc.name = "Web Channel #{show_data["web_channel_id"]}"
        end
        show.web_channel = web_channel
        show.network     = nil # remove wrong relation if present

        # Enqueue background job for additional details
        ExtractWebChannelDataJob.perform_later(web_channel.external_id) if web_channel.description.blank?

      elsif show_data["network_id"].present?
        network = Network.find_or_create_by!(external_id: show_data["network_id"]) do |n|
          n.name = "Network #{show_data["network_id"]}"
        end
        show.network     = network
        show.web_channel = nil # remove wrong relation if present

        # Enqueue background job for additional details
        ExtractNetworkDataJob.perform_later(network.external_id) if network.description.blank?
      end

      # Update remaining attributes
      show.assign_attributes(
        title:             show_data["title"],
        description:       show_data["description"],
        show_type:         show_data["show_type"],
        official_site_url: show_data["official_site_url"],
        genres:            show_data["genres"],
        vote:              show_data["vote"]
      )

      show.save!
    end

    show
  end

  # Convenience helper that iterates over every show (in batches) and syncs it.
  # Returns a hash of statistics { updated:, skipped:, errors: }.
  def self.sync_all
    stats = {
      updated: 0,
      skipped: 0,
      errors:  0
    }

    Show.find_in_batches(batch_size: BATCH_SIZE) do |batch|
      batch.each do |show|
        begin
          result = sync(show)
          if result == :skipped
            stats[:skipped] += 1
          else
            stats[:updated] += 1
          end
        rescue => e
          Rails.logger.error "[ShowSyncService] Error syncing show #{show.id} (external_id: #{show.external_id}): #{e.message}"
          stats[:errors] += 1
        end
      end
    end

    stats
  end
end
