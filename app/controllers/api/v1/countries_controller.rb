module Api
  module V1
    class CountriesController < BaseController
      # GET /api/v1/countries
      # Optional params:
      #   q - Search query for country name (case-insensitive)
      def index
        countries = Country.all
        countries = countries.where("LOWER(name) LIKE ?", "%#{params[:q].downcase}%") if params[:q].present?
        countries = countries.order(:name)

        render json: countries.select(:id, :name, :shortcode)
      end
    end
  end
end
