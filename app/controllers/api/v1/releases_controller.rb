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

        # Capture the total number of releases BEFORE pagination is applied so
        # the client can know when it has fetched everything for infinite scroll.
        total_count = releases.count

        # Apply ordering & pagination after we have the total count
        releases = releases.order(air_date: :asc)
                       .offset(@offset)
                       .limit(@per_page)

        render json: {
          releases: serialize_releases(releases),
          meta: {
            total_count: total_count,
            page: @page,
            per_page: @per_page,
            has_more: (@offset + releases.size) < total_count,
            next_page: (@offset + releases.size) < total_count ? @page + 1 : nil
          }
        }
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
        @page       = params.fetch(:page, 1).to_i
        @per_page   = [ [ params.fetch(:per_page, 20).to_i, 1 ].max, 100 ].min
        @offset     = (@page - 1) * @per_page
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
