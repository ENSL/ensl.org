#!/bin/bash
# ENSL_DB_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ensl_db)

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

docker-compose exec db "mysqldump --opt -u $MYSQL_USER -p $MYSQL_PASSWORD $MYSQL_DATABASE" > $DIR/db/initdb.d/ensl.org.`date +%F`.sql