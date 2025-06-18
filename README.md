# TV Releases

A Rails application for importing and managing upcoming TV show releases from TVMaze.com.

## 📖 Documentation

For detailed information about the TV releases import system, see the [Development Summary](DEVELOPMENT_SUMMARY.md).

## Quick Start

### Import TV Releases

```bash
# Import upcoming releases only
rake releases:import

# Clean up old releases only  
rake releases:cleanup

# Run both import and cleanup
rake releases:maintain
```

### Setup Daily Automation

See [CRON_SETUP.md](CRON_SETUP.md) for instructions on setting up daily automated imports.

## Development

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

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
