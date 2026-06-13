CREATE TABLE IF NOT EXISTS tracks (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  source TEXT,
  file_path TEXT,
  json TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_tracks_type ON tracks(type);
CREATE INDEX IF NOT EXISTS idx_tracks_file_path ON tracks(file_path);

CREATE TABLE IF NOT EXISTS playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  is_local INTEGER NOT NULL DEFAULT 0,
  source TEXT,
  json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS playlist_tracks (
  playlist_id TEXT NOT NULL,
  track_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  added_at TEXT NOT NULL,
  PRIMARY KEY (playlist_id, track_id),
  FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
  FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS liked_tracks (
  track_id TEXT NOT NULL,
  source TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (track_id, source)
);

CREATE TABLE IF NOT EXISTS play_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  track_id TEXT NOT NULL,
  played_at TEXT NOT NULL,
  duration_ms INTEGER,
  source TEXT
);

CREATE INDEX IF NOT EXISTS idx_play_history_track_id ON play_history(track_id);
CREATE INDEX IF NOT EXISTS idx_play_history_played_at ON play_history(played_at);

CREATE TABLE IF NOT EXISTS app_data (
  id TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
