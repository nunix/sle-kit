CREATE TABLE Sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE Timeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    actor TEXT,
    event_type TEXT,
    content TEXT
);
CREATE TABLE ActiveSession (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            session_id INTEGER,
            FOREIGN KEY(session_id) REFERENCES Sessions(id)
        );
CREATE TABLE objectives (id INTEGER PRIMARY KEY AUTOINCREMENT, goal TEXT, status TEXT);
CREATE TABLE alerts (id INTEGER PRIMARY KEY AUTOINCREMENT, warning TEXT);
CREATE TABLE action_log (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP, actor TEXT, action TEXT);
