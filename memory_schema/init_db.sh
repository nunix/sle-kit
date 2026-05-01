#!/bin/bash
mkdir -p ~/.sle-kit/memory/sessions
mkdir -p ~/.sle-kit/temp

echo "Initializing PostgreSQL databases..."
# Ensure user and db exist (requires postgres user access, or run as root)
if [ "$EUID" -eq 0 ]; then
    su - postgres -c "psql -c \"CREATE USER nunix WITH PASSWORD 'nunix';\" || true"
    su - postgres -c "psql -c \"CREATE DATABASE ship_state OWNER nunix;\" || true"
else
    echo "Please ensure PostgreSQL is running and the 'nunix' user and 'ship_state' database exist."
    echo "You can run: sudo -u postgres psql -c \"CREATE USER nunix WITH PASSWORD 'nunix';\""
    echo "           sudo -u postgres psql -c \"CREATE DATABASE ship_state OWNER nunix;\""
fi

# Initialize ship_state and timeline tables
psql postgresql://nunix:nunix@localhost/ship_state -c "CREATE TABLE IF NOT EXISTS objectives (id SERIAL PRIMARY KEY, task TEXT, status TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
psql postgresql://nunix:nunix@localhost/ship_state -c "CREATE TABLE IF NOT EXISTS alerts (id SERIAL PRIMARY KEY, alert_text TEXT, severity TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
psql postgresql://nunix:nunix@localhost/ship_state -c "CREATE TABLE IF NOT EXISTS action_log (id SERIAL PRIMARY KEY, actor TEXT, action TEXT, details TEXT, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"

psql postgresql://nunix:nunix@localhost/ship_state -c "CREATE TABLE IF NOT EXISTS Sessions (id SERIAL PRIMARY KEY, name TEXT UNIQUE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);"
psql postgresql://nunix:nunix@localhost/ship_state -c "CREATE TABLE IF NOT EXISTS Timeline (id SERIAL PRIMARY KEY, session_id INTEGER, timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, actor TEXT, event_type TEXT, content TEXT);"
psql postgresql://nunix:nunix@localhost/ship_state -c "CREATE TABLE IF NOT EXISTS ActiveSession (id INTEGER PRIMARY KEY CHECK (id = 1), session_id INTEGER REFERENCES Sessions(id));"

psql postgresql://nunix:nunix@localhost/ship_state -c "INSERT INTO Sessions (id, name) VALUES (1, 'default') ON CONFLICT (name) DO NOTHING;"
psql postgresql://nunix:nunix@localhost/ship_state -c "INSERT INTO ActiveSession (id, session_id) VALUES (1, 1) ON CONFLICT (id) DO NOTHING;"

echo "Database initialization complete."
