# Sidekiq: Run and Manually Trigger Jobs

This project uses Sidekiq with Redis and defines these workers in `app/workers`:

- `ServerMetadataSyncJob`
- `GithubReleaseAssetSyncJob`
- `DataFileSyncJob`
- `AnalysisBatchImportJob`

## 1. Start Sidekiq

### Docker Compose (recommended in this repo)

From project root:

```bash
source script/env.sh .env .env.development .env.local .env.development.local
make perms
docker compose --profile development up --build development sidekiq
```

To start only Sidekiq (if app is already running):

```bash
docker compose --profile development up --build sidekiq
```

### Local (non-Docker)

If you run Ruby/Rails directly on your machine:

```bash
source script/env.sh .env .env.development .env.local .env.development.local
bundle exec sidekiq
```

## 2. Open a Rails console

### Docker

```bash
docker compose --profile development exec -u web development bin/rails c
```

### Local

```bash
bin/rails c
```

## 3. Enqueue jobs manually

In Rails console, use `perform_async` to push work to Sidekiq.

```ruby
ServerMetadataSyncJob.perform_async
DataFileSyncJob.perform_async
GithubReleaseAssetSyncJob.perform_async
```

For `AnalysisBatchImportJob`, pass a valid batch id:

```ruby
AnalysisBatchImportJob.perform_async(batch_id)
```

Example:

```ruby
batch_id = AnalysisBatch.last&.id
AnalysisBatchImportJob.perform_async(batch_id) if batch_id
```

## 4. Run immediately (without Sidekiq worker process)

Useful for debugging inside console:

```ruby
ServerMetadataSyncJob.new.perform
DataFileSyncJob.new.perform
GithubReleaseAssetSyncJob.new.perform
AnalysisBatchImportJob.new.perform(batch_id)
```

Note: this runs inline in the console process and bypasses Sidekiq queueing/retries.

## 5. Pass options to jobs that support them

`GithubReleaseAssetSyncJob` accepts an optional `repo` option:

```ruby
GithubReleaseAssetSyncJob.perform_async({ "repo" => "ENSL/NS" })
```

`DataFileSyncJob` and `ServerMetadataSyncJob` accept an optional options hash but can be called without args.

## 6. Check queue health

In Rails console:

```ruby
Sidekiq::Queue.new("default").size
Sidekiq::Workers.new.size
Sidekiq::RetrySet.new.size
Sidekiq::DeadSet.new.size
```

## 7. Notes specific to this app

- Redis URL is configured in `config/initializers/sidekiq.rb` using `REDIS_URL`, defaulting to `redis://redis:6379/1`.
- A cron job is registered at Sidekiq startup:
  - `ServerMetadataSyncJob` every 5 minutes.
- Worker queue options are currently `queue: :default`.

## 8. Handy one-liners (Docker)

Enqueue a job without opening an interactive console:

```bash
docker compose --profile development exec -u web development \
  bin/rails runner 'ServerMetadataSyncJob.perform_async'

docker compose --profile development exec -u web development \
  bin/rails runner 'DataFileSyncJob.perform_async'

docker compose --profile development exec -u web development \
  bin/rails runner 'GithubReleaseAssetSyncJob.perform_async'

docker compose --profile development exec -u web development \
  bin/rails runner 'AnalysisBatchImportJob.perform_async(AnalysisBatch.last.id)'
```

If there is no `AnalysisBatch` record yet, create/select one first.
