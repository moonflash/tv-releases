# TV Releases

A Rails application for importing and managing upcoming TV show releases from TVMaze.com.

## 📖 Documentation

For detailed information about the TV releases import system, see the [Development Summary](DEVELOPMENT_SUMMARY.md).

## Quick Start

### STEPS:

```bash
# build rails image
 docker compose -f docker-compose.dev.yml build --no-cache web

# start services without worker
docker compose -f docker-compose.dev.yml up --scale worker=0

# Run import script
docker exec -it tv-releases-web-1 bundle exec rake releases:import

#  only after import script finished run workers
docker compose -f docker-compose.dev.yml up --scale worker=4
```
### IMPORTANT!
due to the lack of time to investigate it's capabilities, Crawl4ai service is set to be only single threaded. Because of that we are firstly importing releases and only after that we run workers that will call Show/Network/Episodes endpoints to scrape data. Documentation suggests that it can be multithreaded and with Crawl4ai properly set we should have unlimited parallel processes to handle import much faster.

## ReactJS frontend

http://localhost:3000

### Setup Daily Automation

See [CRON_SETUP.md](CRON_SETUP.md) for instructions on setting up daily automated imports.

## Database Schema

Below is a high-level entity-relationship diagram (ERD) of the persistent models used by TV Releases.  


```text
+-----------+     1        *  +-----------+
| countries |-----------------| networks  |
+-----------+                 +-----------+
                                  | 0..1
                                  v
                             +-----------+
                             |  shows    |
+-----------+     *      0..1 +-----------+
| web_chan- |-----------------|
| nels      |                 |
+-----------+                 |
                              | 1        *
                              v
                         +-----------+
                         | episodes  |
                         +-----------+
                              | 1        *
                              v
                         +-----------+
                         | releases  |
                         +-----------+
```

                        Each `release` belongs to an `episode`, which in turn
                        belongs to a `show`. A `show` is broadcast either on a
                        traditional `network` (optionally linked to a `country`) or on a
                        `web_channel` (for streaming services).

## Docker Development Setup

1. Start the full stack (PostgreSQL, Rails web, crawler and four background workers):

```bash
docker compose -f docker-compose.dev.yml up --build --scale worker=4
```

   * `--build` ensures the Rails image is rebuilt when you change code.
   * `--scale worker=4` starts four `worker` containers so background jobs are processed in parallel.

2. Open another terminal tab/window and run any Rake tasks inside the `web` service. For example:

```bash
# Import upcoming releases only
docker compose exec web rake releases:import

# Clean up old releases only
docker compose exec web rake releases:cleanup

# Run both import and cleanup
docker compose exec web rake releases:maintain
```

3. When you are finished, stop and remove the containers with:

```bash
docker compose -f docker-compose.dev.yml down
```

---

# Summary

### Crawl4a
- This App is using [Crawl4ai](https://docs.crawl4ai.com/) for scraping urls. 
We used just a small % of it's capabilities (this is the first time I'm using it and could not waste time exparimenting too long).
- using gemma3:27b inferenced on my own hardware (open to public just for this test)
    - we are sccaping main countdown list of releases
    - for each realease we extract date/time, show_id, network_id, episode_id
    - then we scrape 
        - show page and create Show (title, show_type, official_site_url, description ...)
        - episode page and create Episode (title, description, num/season ... )
        - network page and create Network (tile, description ...)

### Jobs
- Since we are using LLM and the whole scraping process is long we've introduced async jobs for Show/Episode/Network scraping

### Data
- we have separate model for Release, Show, Network, Episode, Country. And there is appropriate releation between all of them

### API
- api can be reached on:
```
      GET /api/v1/releases
       Supports filters:
         country   - ISO shortcode of the country (e.g., "US")
         network   - Network ID
         start_date / end_date - YYYY-MM-DD range filter on air_date
         q         - Search query for show title (case-insensitive)
         page / per_page - Pagination params (defaults: page=1, per_page=20, capped at 100)
```
It is not adjusted to take all the advantages of carefully collected data and there is a room for improvement here.

### Frontend
- we are using very simple reactjs list that is not taking full advantage even of this "low level" API 



## Production ?

- there is just a simple [GitHub Actions example](.github/workflows/production.yml) of how to deploy this code on AWS with a Docker Swarm implementation. Since it's not going to production I left the database inside Swarm, which would otherwise go to RDS...





# Final words
It took me 8 hours to build this and as much as i hurts to "ship" something that is almost unusable I have to stop and present you what's done  :) 




