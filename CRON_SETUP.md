# Setting up Daily TV Releases Import

## Cron Job Setup

To run the TV releases import daily, add the following cron job:

```bash
# Edit crontab
crontab -e

# Add this line to run every day at 2 AM
0 2 * * * cd /path/to/your/tv-releases && /usr/local/bin/bundle exec rake releases:maintain RAILS_ENV=production >> /var/log/tv-releases-import.log 2>&1
```

## Manual Usage

You can also run the tasks manually:

```bash
# Import upcoming releases only
rake releases:import

# Clean up old releases only  
rake releases:cleanup

# Run both import and cleanup
rake releases:maintain
```

## Docker Usage

If running in Docker:

```bash
# Add to your docker-compose.yml services
cron-service:
  image: your-app-image
  command: >
    sh -c "echo '0 2 * * * cd /app && bundle exec rake releases:maintain RAILS_ENV=production >> /var/log/cron.log 2>&1' | crontab - && crond -f"
  volumes:
    - ./logs:/var/log
  depends_on:
    - db
```

## Logging

The rake tasks log their activity to the Rails logger. In production, check:
- Application logs for detailed processing information
- Cron logs for task execution status

## Monitoring

Monitor the following:
- Number of releases imported daily
- Any error messages in logs
- Database growth (cleanup task removes old releases)
- External API availability (TVMaze.com)

## Troubleshooting

Common issues:
1. **Network connectivity**: Ensure the server can reach TVMaze.com
2. **Database locks**: If long-running, ensure proper database timeout settings
3. **Memory usage**: Large imports may require adequate memory allocation
4. **API rate limits**: The crawler service handles rate limiting internally 