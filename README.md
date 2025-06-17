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
