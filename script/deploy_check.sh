#!/usr/bin/env bash
set -euo pipefail

db_exec() {
	docker compose exec -T "${DB_SERVICE:-db}" "$@"
}

mysql_exec() {
	local -a args=(
		mysql
		--protocol=tcp
		--host="${MYSQL_HOST:-127.0.0.1}"
		--port="${MYSQL_PORT:-3306}"
		--user="${MYSQL_USER:-root}"
		--batch
		--raw
		--skip-column-names
		-e "$1"
	)
	[[ -n "${MYSQL_PASSWORD:-}" ]] && args+=(--password="${MYSQL_PASSWORD}")
	db_exec "${args[@]}"
}

mysqlcheck_exec() {
	local -a args=(
		mysqlcheck
		--protocol=tcp
		--host="${MYSQL_HOST:-127.0.0.1}"
		--port="${MYSQL_PORT:-3306}"
		--user="${MYSQL_USER:-root}"
		--check
		--databases
	)
	[[ -n "${MYSQL_PASSWORD:-}" ]] && args+=(--password="${MYSQL_PASSWORD}")
	args+=("$@")
	db_exec "${args[@]}"
}

main() {
	echo "Checking MySQL connectivity..."
	mysql_exec "SELECT 1;" >/dev/null

	echo "Fetching non-system databases..."
	mapfile -t databases < <(mysql_exec "
		SELECT SCHEMA_NAME
		FROM information_schema.schemata
		WHERE SCHEMA_NAME NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
		ORDER BY SCHEMA_NAME;
	")

	if [[ ${#databases[@]} -eq 0 ]]; then
		echo "No user databases found to check."
		exit 0
	fi

	echo "Running mysqlcheck on ${#databases[@]} databases..."
	mysqlcheck_exec "${databases[@]}"

	echo "MySQL integrity check passed for all tables."
}

main
