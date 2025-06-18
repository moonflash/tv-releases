module Api
  module V1
    class WebChannelsController < BaseController
      # GET /api/v1/web_channels
      # Optional params:
      #   q - Search query for web channel name (case-insensitive)
      def index
        channels = WebChannel.all
        channels = channels.where("LOWER(name) LIKE ?", "%#{params[:q].downcase}%") if params[:q].present?
        channels = channels.order(:name)

        render json: channels.select(:id, :name)
      end
    end
  end
end
