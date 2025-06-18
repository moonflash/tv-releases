class Show < ApplicationRecord
  belongs_to :network, optional: true
  belongs_to :web_channel, optional: true
  has_many :episodes, dependent: :destroy
  has_many :releases, through: :episodes

  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true, on: :update
  validate  :network_or_web_channel_present

  def self.find_or_create_from_external_id(external_id, network_or_options = nil, **options)
    # Flexible invocation: second positional can be network, or a hash of options; keywords also accepted.
    if network_or_options.is_a?(Hash)
      opts = network_or_options
      network     = opts[:network]
      web_channel = opts[:web_channel]
    else
      network     = network_or_options || options[:network]
      web_channel = options[:web_channel]
    end

    return nil if external_id.blank?

    new_record = false

    show = find_or_create_by(external_id: external_id) do |s|
      s.network = network if network.present?
      s.web_channel = web_channel if web_channel.present?
      new_record = true
    end

    # If it belongs to a network or web_channel enqueue appropriate data extraction job
    if network.present? && (new_record || show.network&.description.blank?)
      ExtractNetworkDataJob.perform_later(network.external_id)
    elsif web_channel.present? && (new_record || show.web_channel&.description.blank?)
      ExtractWebChannelDataJob.perform_later(web_channel.external_id)
    end

    show
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Show] Error creating show #{external_id}: #{e.message}"
    # In case of race condition, try to find again
    find_by(external_id: external_id)
  rescue => e
    Rails.logger.error "[Show] Exception creating show #{external_id}: #{e.message}"
    nil
  end

  private

  def network_or_web_channel_present
    if network.nil? && web_channel.nil?
      errors.add(:base, "Show must belong to a network or web channel")
    end
  end
end
