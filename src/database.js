/**
 * SQLite database module for MCP SSH Keychain
 * Stores command execution history with WAL mode for concurrent access
 */

import Database from 'better-sqlite3';
import { mkdirSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { homedir } from 'os';
import { nanoid } from 'nanoid';

const DATA_DIR = join(homedir(), '.local', 'share', 'mcp-ssh-keychain');
const DB_PATH = join(DATA_DIR, 'history.db');

let db = null;

/**
 * Get database instance (singleton pattern)
 */
export function getDb() {
  if (db) return db;
  
  // Ensure data directory exists
  if (!existsSync(DATA_DIR)) {
    mkdirSync(DATA_DIR, { recursive: true });
  }
  
  // Initialize database
  db = new Database(DB_PATH);
  
  // Enable WAL mode for better concurrent access
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  
  return db;
}

/**
 * Initialize database schema
 */
export function initializeDatabase() {
  const db = getDb();
  
  db.exec(`
    CREATE TABLE IF NOT EXISTS command_history (
      id TEXT PRIMARY KEY,
      timestamp TEXT NOT NULL,
      host TEXT NOT NULL,
      user TEXT NOT NULL,
      port INTEGER DEFAULT 22,
      command TEXT NOT NULL,
      exit_code INTEGER,
      stdout TEXT,
      stderr TEXT,
      duration_ms INTEGER,
      session_id TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_command_history_host_timestamp 
      ON command_history(host, timestamp);
  `);
  
  return db;
}

/**
 * Close database connection with WAL checkpoint
 */
export function closeDatabase() {
  if (db) {
    // Checkpoint WAL file before closing (TRUNCATE mode removes WAL file)
    try {
      db.pragma('wal_checkpoint(TRUNCATE)');
    } catch (error) {
      // Ignore checkpoint errors during shutdown
    }
    
    db.close();
    db = null;
  }
}

/**
 * Insert command execution record
 */
export function insertCommandHistory(record) {
  const db = getDb();
  
  const stmt = db.prepare(`
    INSERT INTO command_history (
      id, timestamp, host, user, port, command, 
      exit_code, stdout, stderr, duration_ms, session_id
    ) VALUES (
      @id, @timestamp, @host, @user, @port, @command,
      @exit_code, @stdout, @stderr, @duration_ms, @session_id
    )
  `);
  
  return stmt.run({
    id: record.id || nanoid(),
    timestamp: record.timestamp || new Date().toISOString(),
    host: record.host,
    user: record.user,
    port: record.port || 22,
    command: record.command,
    exit_code: record.exit_code ?? null,
    stdout: record.stdout ?? null,
    stderr: record.stderr ?? null,
    duration_ms: record.duration_ms ?? null,
    session_id: record.session_id ?? null
  });
}

/**
 * Query command history
 */
export function queryCommandHistory(filters = {}, limit = 100) {
  const db = getDb();
  
  let query = 'SELECT * FROM command_history WHERE 1=1';
  const params = {};
  
  if (filters.host) {
    query += ' AND host = @host';
    params.host = filters.host;
  }
  
  if (filters.user) {
    query += ' AND user = @user';
    params.user = filters.user;
  }
  
  if (filters.session_id) {
    query += ' AND session_id = @session_id';
    params.session_id = filters.session_id;
  }
  
  if (filters.since) {
    query += ' AND timestamp >= @since';
    params.since = filters.since;
  }
  
  query += ' ORDER BY timestamp DESC LIMIT @limit';
  params.limit = limit;
  
  const stmt = db.prepare(query);
  return stmt.all(params);
}
