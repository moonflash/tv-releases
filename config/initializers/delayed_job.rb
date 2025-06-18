# Keep failed Delayed Job records so they can be inspected and retried later
# See https://github.com/collectiveidea/delayed_job#failures

if defined?(Delayed)
  # Do not delete jobs from the delayed_jobs table once they hit the max_attempts limit.
  # They will have `failed_at` set which allows querying them via the Delayed::Job model.
  Delayed::Worker.destroy_failed_jobs = false

  # Optional: tweak the maximum number of attempts before a job is considered failed.
  # Keeping it at the gem default (25) unless overridden via ENV.
  Delayed::Worker.max_attempts = Integer(ENV.fetch("DJ_MAX_ATTEMPTS", 25))

  # Reduce the default wait time before a failed job is retried to speed up feedback.
  Delayed::Worker.max_run_time = 10.minutes
end
