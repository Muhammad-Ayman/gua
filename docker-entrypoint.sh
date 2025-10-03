#!/bin/bash
set -e

# Start PostgreSQL temporarily to initialize it
/etc/init.d/postgresql start

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -p 5432 -U postgres
do
  echo "Waiting for PostgreSQL to start..."
  sleep 1
done

# Initialize the database with the schema
psql -U postgres -d postgres -f /docker-entrypoint-initdb.d/initdb.sql

# Stop PostgreSQL
/etc/init.d/postgresql stop

# Start Supervisor to run all services
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
