module Api
  module V1
    class ReleasesController < BaseController
      before_action :set_pagination_params

      # GET /api/v1/releases
      # Supports filters:
      #   country   - ISO shortcode of the country (e.g., "US")
      #   network   - Network ID
      #   start_date / end_date - YYYY-MM-DD range filter on air_date
      #   q         - Search query for show title (case-insensitive)
      #   page / per_page - Pagination params (defaults: page=1, per_page=20, capped at 100)
      def index
        releases = Release
                     .joins(episode: { show: { network: :country } })
                     .includes(episode: { show: { network: :country } })

        releases = apply_filters(releases)
        releases = releases.order(air_date: :asc)
        releases = releases.offset(@offset).limit(@per_page)

        render json: serialize_releases(releases)
      end

      private

      def apply_filters(scope)
        scope = scope.where(countries: { shortcode: params[:country] }) if params[:country].present?
        scope = scope.where(networks: { id: params[:network] }) if params[:network].present?

        if params[:start_date].present?
          scope = scope.where("releases.air_date >= ?", params[:start_date])
        end

        if params[:end_date].present?
          scope = scope.where("releases.air_date <= ?", params[:end_date])
        end

        if params[:q].present?
          query = "%#{params[:q].downcase}%"
          scope = scope.where("LOWER(shows.title) LIKE ?", query)
        end

        scope
      end

      def set_pagination_params
        page_param = params.fetch(:page, 1).to_i
        @per_page   = [ [ params.fetch(:per_page, 20).to_i, 1 ].max, 100 ].min
        @offset     = (page_param - 1) * @per_page
      end

      # Minimal JSON serializer without external dependencies
      def serialize_releases(collection)
        collection.map do |release|
          {
            id: release.id,
            air_date: release.air_date,
            air_time: release.air_time.strftime("%H:%M:%S"),
            episode: {
              id: release.episode.id,
              season_number: release.episode.season_number,
              episode_number: release.episode.episode_number,
              airdate: release.episode.airdate,
              runtime: release.episode.runtime,
              summary: release.episode.summary,
              external_id: release.episode.external_id,
              show: {
                id: release.show.id,
                title: release.show.title,
                show_type: release.show.show_type,
                network: {
                  id: release.network.id,
                  name: release.network.name,
                  country: {
                    id: release.country.id,
                    name: release.country.name,
                    shortcode: release.country.shortcode
                  }
                }
              }
            }
          }
        end
      end
    end
  end
end
