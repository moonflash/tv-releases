module Api
  module V1
    class NetworksController < BaseController
      # GET /api/v1/networks
      # Optional params:
      #   country - ISO shortcode to filter networks by country
      #   q       - Search query for network name (case-insensitive)
      def index
        networks = Network.all
        networks = networks.joins(:country).where(countries: { shortcode: params[:country].upcase }) if params[:country].present?
        networks = networks.where("LOWER(networks.name) LIKE ?", "%#{params[:q].downcase}%") if params[:q].present?
        networks = networks.order(:name)

        render json: networks.select(:id, :name)
      end
    end
  end
end
