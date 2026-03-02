/**
 * SSH Command History Module
 * Provides functions to record and query SSH command execution history
 */

import { nanoid } from 'nanoid';
import { getDb } from './database.js';

/**
 * Record a command execution in history
 * @param {Object} record - Command execution record
 * @param {string} record.host - Remote host
 * @param {string} record.user - SSH user
 * @param {number} [record.port=22] - SSH port
 * @param {string} record.command - Executed command
 * @param {number} [record.exit_code] - Command exit code
 * @param {string} [record.stdout] - Command stdout
 * @param {string} [record.stderr] - Command stderr
 * @param {number} [record.duration_ms] - Execution duration in milliseconds
 * @param {string} [record.session_id] - Session identifier
 * @returns {Object} Insert result with lastInsertRowid and changes
 */
export function recordCommand(record) {
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
    id: nanoid(),
    timestamp: new Date().toISOString(),
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
 * Query command history with filters (list view - excludes stdout/stderr)
 * @param {Object} [filters={}] - Query filters
 * @param {string} [filters.host] - Filter by host
 * @param {string} [filters.user] - Filter by user
 * @param {string} [filters.commandFilter] - Filter by command (LIKE pattern)
 * @param {string} [filters.session_id] - Filter by session ID
 * @param {number} [limit=100] - Maximum number of results
 * @returns {Array} Array of command history records (without stdout/stderr)
 */
export function queryHistory(filters = {}, limit = 100) {
  const db = getDb();
  
  // List view: exclude stdout/stderr (too large)
  let query = `
    SELECT id, timestamp, host, user, port, command, exit_code, duration_ms, session_id
    FROM command_history 
    WHERE 1=1
  `;
  const params = {};
  
  if (filters.host) {
    query += ' AND host = @host';
    params.host = filters.host;
  }
  
  if (filters.user) {
    query += ' AND user = @user';
    params.user = filters.user;
  }
  
  if (filters.commandFilter) {
    query += ' AND command LIKE @commandFilter';
    params.commandFilter = `%${filters.commandFilter}%`;
  }
  
  if (filters.session_id) {
    query += ' AND session_id = @session_id';
    params.session_id = filters.session_id;
  }
  
  query += ' ORDER BY timestamp DESC LIMIT @limit';
  params.limit = limit;
  
  const stmt = db.prepare(query);
  return stmt.all(params);
}

/**
 * Get full command details including stdout/stderr
 * @param {string} id - Command history record ID
 * @returns {Object|null} Full command record or null if not found
 */
export function getCommandDetail(id) {
  const db = getDb();
  
  const stmt = db.prepare(`
    SELECT * FROM command_history WHERE id = ?
  `);
  
  return stmt.get(id) || null;
}
