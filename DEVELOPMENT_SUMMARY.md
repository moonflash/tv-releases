# TV Releases Platform – Development Summary (Updated June 2025)

## Overview

The platform ingests upcoming TV releases from TVMaze.com for the next 90 days, enriches them with show / episode / network meta-data and exposes the data through a JSON API consumed by a small React UI.  The backend is a Ruby on Rails application with Sidekiq‐style background jobs; the frontend lives in the `app/javascript` folder and is bundled by Webpacker.

---

## 1  Domain Models

1. **Country (`app/models/country.rb`)**
   • Attributes: `name`, `shortcode` (ISO-3166)  
   • Associations: has many `networks → shows → episodes → releases`  
   • Class helper: `find_or_create_by_shortcode` for idempotent upserts

2. **Network (`app/models/network.rb`)**
   • Belongs to **Country** (optional)  
   • Has many **Shows / Episodes / Releases** (through associations)  
   • Validations on `name` & `external_id` uniqueness  
   • Automatic name normalisation – strips *"TV / Network / Channel"* etc. and handles special cases (HBO, BBC…)

3. **Show (`app/models/show.rb`)**
   • Belongs to **Network**  
   • Has many **Episodes** and **Releases**  
   • `find_or_create_from_external_id` builds stub records and triggers async metadata extraction

4. **Episode (`app/models/episode.rb`)**
   • Belongs to **Show**  
   • Has many **Releases**  
   • Validations ensure `(season_number, episode_number)` uniqueness per show once details are fetched  
   • Helper `title` returns `S01E05`-style label

5. **Release (`app/models/release.rb`)**
   • Belongs to **Episode**  
   • Scopes: `upcoming`, `within_days(n)`  
   • `find_or_create_from_crawl_data` orchestrates minimal network / show / episode stub creation and queues extraction jobs. Duplicate releases (same episode + air date/time) are skipped.



---

## 2  Background Jobs

| Job | Purpose |
|-----|---------|
| `ExtractNetworkDataJob` | Fetches full network meta-data (timezone, description, official URL, country) |
| `ExtractShowDataJob`    | Enriches stub shows with title, genres, vote, etc. |
| `ExtractEpisodeDataJob` | Populates season / episode numbers, runtime, summary |

All jobs rely on `Crawl4aiService` and log non-fatal failures without interrupting the import pipeline.

---

## 3  Service Layer

**ReleaseImportService (`app/services/release_import_service.rb`)**

* Crawls TVMaze paginated release feed until the 90-day cut-off is reached.
* Skips duplicates early, batches DB writes and returns `{ imported:, skipped:, errored: }` counters.
* Delegates enrichment to the background jobs above.

---

## 4  Public JSON API (controllers in `app/controllers/api/v1`)

1. `GET /api/v1/countries` – optional `q` param (case-insensitive search)
2. `GET /api/v1/networks` – filters: `country`, `q`
3. `GET /api/v1/releases` – filters & pagination:
   • `country`, `network`, `start_date`, `end_date`, `q`  
   • `page` & `per_page` (capped at 100)

Responses are plain JSON produced by a hand-rolled serializer (no ActiveModelSerializers dependency).

---

## 5  React Front-end (`app/javascript/components`)

* `App.jsx` – entry point mounted by Webpacker.
* `ReleasesPage.jsx` – functional component that:
  1. Fetches countries on mount.
  2. Dynamically loads networks when a country is selected.
  3. Fetches releases every time filters change (uses `URLSearchParams`).
  4. Renders filter UI and paginated release list; shows loading & error states.

The component tree is small but showcases how the API can be consumed; it can be dropped into Rails views via `javascript_pack_tag` or server-side rendering.

---

## 6  Database Schema (key columns only)

```
Countries   id, name, shortcode
Networks    id, name, external_id, country_id, description, time_zone, official_site_url
Shows       id, title, external_id, network_id, show_type, genres
Episodes    id, external_id, show_id, season_number, episode_number, airdate, runtime
Releases    id, episode_id, air_date, air_time
```

Foreign keys cascade deletes from top → bottom (country → network → show → episode → release) to keep data consistent and lean.

---

## 7  Rake Tasks (`lib/tasks/releases.rake`)

* `releases:import`   – run `ReleaseImportService`
* `releases:cleanup`  – purge releases older than 7 days
* `releases:maintain` – convenience wrapper (import + cleanup) – ideal for cron:

```bash
0 2 * * * cd /app && bundle exec rake releases:maintain RAILS_ENV=production
```

---

## 8  Test Suite Snapshot

* **Models:** country (8), network (15), show (10), episode (10), release (12)
* **Services:** ReleaseImportService (20)
* **Jobs:** extraction jobs (9)
* **Controllers (requests):** API V1 (12)
* **Rake tasks:** releases tasks (6)

_Total ≈ 90 RSpec examples – all green._  (Exact counts may vary as specs grow.)

---

## 9  Key Technical Decisions & Notes

1. **Incremental enrichment** – core release rows are persisted immediately; heavy meta-data is fetched asynchronously to avoid blocking the crawler.
2. **Name normalisation** – made network matching resilient to upstream naming quirks.
3. **Pagination & filtering** – kept in SQL, avoiding in-memory filtering for large datasets.
4. **No external serializer gem** – custom JSON ensures zero serialization overhead.
5. **React as progressive enhancement** – the Rails app still renders traditional HTML; React bundle is optional.

---

## 10  Roadmap

1. **Multithreaded Crawl4ai** – it has that capability and it should be enabled
2. **We are using only 4 RTX Nvidia cares** – for production should be used cheap [Gemma3-27b](https://deepinfra.com/google/gemma-3-27b-it) model from https://deepinfra.com
3. **images or any other data can be imported easely** 
4. **Smart Search** – We shoudl embed extracted data and allow semantic vector search, and smart suggestions
5. **Front-end** – with rich data structure we are capable to offer much more than scraped website

---

_Last updated: 18 June 2025_ 