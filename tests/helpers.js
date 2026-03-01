import { MockClient } from './mocks/ssh2.js';
import * as mockKeychain from './mocks/cross-keychain.js';
import MockDatabase from './mocks/better-sqlite3.js';

export function createMockConnection(options = {}) {
  const defaults = {
    shouldFail: false,
    execResults: {},
    sftpOptions: {},
    shellOptions: {}
  };

  return new MockClient({ ...defaults, ...options });
}

export function createMockKeychain() {
  mockKeychain.clearStore();
  
  return {
    getPassword: mockKeychain.getPassword,
    setPassword: mockKeychain.setPassword,
    deletePassword: mockKeychain.deletePassword,
    clearStore: mockKeychain.clearStore
  };
}

export function createMockDb(filename = ':memory:', options = {}) {
  const defaults = {
    shouldFail: false
  };

  const db = new MockDatabase(filename, { ...defaults, ...options });
  
  db.exec(`
    CREATE TABLE IF NOT EXISTS connections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL,
      host TEXT NOT NULL,
      port INTEGER DEFAULT 22,
      username TEXT NOT NULL,
      auth_type TEXT NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  `);

  db.exec(`
    CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      connection_id INTEGER NOT NULL,
      session_id TEXT UNIQUE NOT NULL,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      last_activity TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (connection_id) REFERENCES connections(id)
    )
  `);

  return db;
}

export function createTestConnection(db, overrides = {}) {
  const defaults = {
    name: 'test-server',
    host: 'test.example.com',
    port: 22,
    username: 'testuser',
    auth_type: 'password'
  };

  const connection = { ...defaults, ...overrides };
  
  const stmt = db.prepare(`
    INSERT INTO connections (name, host, port, username, auth_type)
    VALUES (?, ?, ?, ?, ?)
  `);

  const result = stmt.run(
    connection.name,
    connection.host,
    connection.port,
    connection.username,
    connection.auth_type
  );

  return {
    id: result.lastInsertRowid,
    ...connection
  };
}

export function createTestSession(db, connectionId, overrides = {}) {
  const defaults = {
    session_id: `session-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  };

  const session = { ...defaults, ...overrides };
  
  const stmt = db.prepare(`
    INSERT INTO sessions (connection_id, session_id)
    VALUES (?, ?)
  `);

  const result = stmt.run(connectionId, session.session_id);

  return {
    id: result.lastInsertRowid,
    connection_id: connectionId,
    ...session
  };
}

export async function setupTestPassword(keychain, service, account, password) {
  await keychain.setPassword(service, account, password);
}

export function waitForEvent(emitter, event, timeout = 1000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`Timeout waiting for event: ${event}`));
    }, timeout);

    emitter.once(event, (...args) => {
      clearTimeout(timer);
      resolve(args);
    });
  });
}
