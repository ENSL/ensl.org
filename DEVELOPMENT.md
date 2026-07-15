# Development

Install steps are in [[INSTALL.md]].

## Quick start (development)

1. Load environment variables (required):

    source script/env.sh .env .env.development .env.local .env.development.local

2. Fix mounted-volume permissions (run once before first startup, and again if ownership changes):

    make perms

3. Start the development app:

    docker compose --profile development up --build development

4. Optional: run Sidekiq too:

    docker compose --profile development up --build development sidekiq

The app container runs `bin/script/entry.sh`, which loads env files, runs `bundle install`, runs migrations, and starts Puma (`bin/dev` in development).

## Common commands

Load envs in your shell before running compose/make commands:

    source script/env.sh .env .env.development .env.local .env.development.local

Rebuild images:

    docker compose --profile development build

Restart app container:

    docker compose --profile development restart development

Stop development stack:

    docker compose --profile development down

Open shell in containers:

    docker compose --profile development exec -u web development /bin/bash
    docker compose --profile development exec -u root development /bin/bash

## Testing

Start test container:

    docker compose --profile test up --build -d test

Run all specs:

    docker compose --profile test exec -u web test bundle exec rspec

Run one spec file:

    docker compose --profile test exec -u web test bundle exec rspec spec/controllers/shoutmsgs_controller_spec.rb

Safety guardrails:

- Specs are blocked unless `RAILS_ENV=test` (override only if intentional with `ALLOW_NON_TEST_SPECS=1`).
- Destructive db tasks in development (for example `db:drop`, `db:reset`, `db:schema:load`) are blocked by default.
- To intentionally run a destructive db task in development, set `ALLOW_DESTRUCTIVE_DB_TASKS=1` for that command only.

Example intentional reset in development:

    ALLOW_DESTRUCTIVE_DB_TASKS=1 bin/rails db:reset

Open shell in test container:

    docker compose --profile test exec -u web test /bin/bash

Stop test stack:

    docker compose --profile test down

## Debugging

- For a shell-only app container (do not start Puma), set `DISABLE_PUMA=1` in env and run `docker compose --profile development up development`.
- For Ruby debug server mode, set `RAILS_DEBUG=1` and start development; the entry script runs `rdbg` on port `12345`.
- If container startup fails at migrations, the entry script keeps the container alive for inspection.

## VS Code and containers

Use VS Code container support directly (Dev Containers / Docker extension) to work inside the same environment as Compose services.

- Attach VS Code terminal to running containers instead of maintaining host-specific Ruby setups.
- Run app and test commands from the container terminal for consistent tooling and paths.

## Notes

- Keep secrets and machine-specific overrides in `.env.local` and `.env.<env>.local`.
- Rebuild images when dependencies in `Dockerfile`/gems change.
- For production deployment helpers, see `Makefile` targets: `prep_prod`, `deploy_prod`, `restart_prod_all`, `deploy_check`.
