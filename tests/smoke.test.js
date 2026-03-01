import { describe, it, expect, beforeEach } from 'vitest';
import { MockClient, MockSFTP, MockShellStream } from './mocks/ssh2.js';
import * as mockKeychain from './mocks/cross-keychain.js';
import MockDatabase from './mocks/better-sqlite3.js';
import {
  createMockConnection,
  createMockKeychain,
  createMockDb,
  createTestConnection,
  createTestSession,
  setupTestPassword,
  waitForEvent
} from './helpers.js';

describe('Mock Infrastructure Smoke Tests', () => {
  describe('SSH2 Mock', () => {
    it('should create MockClient and connect successfully', async () => {
      const client = createMockConnection();
      
      const readyPromise = waitForEvent(client, 'ready');
      client.connect({ host: 'test.example.com', username: 'test' });
      
      await readyPromise;
      expect(client.connected).toBe(true);
    });

    it('should handle connection failure', async () => {
      const client = createMockConnection({ shouldFail: true });
      
      const errorPromise = waitForEvent(client, 'error');
      client.connect({ host: 'test.example.com', username: 'test' });
      
      const [error] = await errorPromise;
      expect(error.message).toBe('Connection failed');
    });

    it('should execute commands', async () => {
      const client = createMockConnection({
        execResults: {
          'ls -la': { stdout: 'file1.txt\nfile2.txt\n', code: 0 }
        }
      });

      const readyPromise = waitForEvent(client, 'ready');
      client.connect({ host: 'test.example.com' });
      await readyPromise;

      const execPromise = new Promise((resolve, reject) => {
        client.exec('ls -la', (err, stream) => {
          if (err) return reject(err);
          
          let output = '';
          stream.on('data', data => {
            output += data.toString();
          });
          
          stream.on('close', (code) => {
            resolve({ output, code });
          });
        });
      });

      const result = await execPromise;
      expect(result.output).toBe('file1.txt\nfile2.txt\n');
      expect(result.code).toBe(0);
    });

    it('should create SFTP session', async () => {
      const client = createMockConnection();
      
      const readyPromise = waitForEvent(client, 'ready');
      client.connect({ host: 'test.example.com' });
      await readyPromise;

      const sftpPromise = new Promise((resolve, reject) => {
        client.sftp((err, sftp) => {
          if (err) return reject(err);
          resolve(sftp);
        });
      });

      const sftp = await sftpPromise;
      expect(sftp).toBeInstanceOf(MockSFTP);
    });

    it('should upload file via SFTP', async () => {
      const client = createMockConnection();
      
      const readyPromise = waitForEvent(client, 'ready');
      client.connect({ host: 'test.example.com' });
      await readyPromise;

      const sftp = await new Promise((resolve, reject) => {
        client.sftp((err, sftp) => {
          if (err) return reject(err);
          resolve(sftp);
        });
      });

      const uploadPromise = new Promise((resolve, reject) => {
        sftp.fastPut('/local/file.txt', '/remote/file.txt', (err) => {
          if (err) return reject(err);
          resolve();
        });
      });

      await uploadPromise;
      expect(sftp.files.has('/remote/file.txt')).toBe(true);
    });

    it('should create shell session', async () => {
      const client = createMockConnection();
      
      const readyPromise = waitForEvent(client, 'ready');
      client.connect({ host: 'test.example.com' });
      await readyPromise;

      const shellPromise = new Promise((resolve, reject) => {
        client.shell((err, stream) => {
          if (err) return reject(err);
          resolve(stream);
        });
      });

      const stream = await shellPromise;
      expect(stream).toBeInstanceOf(MockShellStream);
    });

    it('should handle shell commands', async () => {
      const client = createMockConnection();
      
      const readyPromise = waitForEvent(client, 'ready');
      client.connect({ host: 'test.example.com' });
      await readyPromise;

      const stream = await new Promise((resolve, reject) => {
        client.shell((err, stream) => {
          if (err) return reject(err);
          resolve(stream);
        });
      });

      const outputPromise = new Promise((resolve) => {
        let output = '';
        stream.on('data', data => {
          output += data.toString();
        });
        
        setTimeout(() => resolve(output), 50);
      });

      stream.write('echo hello');
      
      const output = await outputPromise;
      expect(output).toContain('echo hello');
    });
  });

  describe('Cross-Keychain Mock', () => {
    beforeEach(() => {
      mockKeychain.clearStore();
    });

    it('should store and retrieve passwords', async () => {
      const keychain = createMockKeychain();
      
      await keychain.setPassword('test-service', 'test-account', 'secret123');
      const password = await keychain.getPassword('test-service', 'test-account');
      
      expect(password).toBe('secret123');
    });

    it('should reject when password not found', async () => {
      const keychain = createMockKeychain();
      
      await expect(
        keychain.getPassword('nonexistent', 'account')
      ).rejects.toThrow('Password not found');
    });

    it('should delete passwords', async () => {
      const keychain = createMockKeychain();
      
      await keychain.setPassword('test-service', 'test-account', 'secret123');
      await keychain.deletePassword('test-service', 'test-account');
      
      await expect(
        keychain.getPassword('test-service', 'test-account')
      ).rejects.toThrow('Password not found');
    });

    it('should reject delete when password not found', async () => {
      const keychain = createMockKeychain();
      
      await expect(
        keychain.deletePassword('nonexistent', 'account')
      ).rejects.toThrow('Password not found');
    });
  });

  describe('Better-SQLite3 Mock', () => {
    it('should create database and prepare statements', () => {
      const db = createMockDb();
      
      expect(db.isOpen).toBe(true);
      
      const stmt = db.prepare('SELECT * FROM connections');
      expect(stmt.sql).toBe('SELECT * FROM connections');
    });

    it('should insert data', () => {
      const db = createMockDb();
      
      const connection = createTestConnection(db, {
        name: 'prod-server',
        host: 'prod.example.com'
      });
      
      expect(connection.id).toBeDefined();
      expect(connection.name).toBe('prod-server');
    });

    it('should execute SQL', () => {
      const db = createMockDb();
      
      db.exec('CREATE TABLE test (id INTEGER PRIMARY KEY)');
      expect(db.isOpen).toBe(true);
    });

    it('should handle pragma', () => {
      const db = createMockDb();
      
      db.pragma('journal_mode', 'WAL');
      const mode = db.pragma('journal_mode');
      
      expect(mode).toBe('WAL');
    });

    it('should close database', () => {
      const db = createMockDb();
      
      db.close();
      expect(db.isOpen).toBe(false);
    });

    it('should create transactions', () => {
      const db = createMockDb();
      
      const insertMany = db.transaction((items) => {
        for (const item of items) {
          createTestConnection(db, item);
        }
      });

      insertMany([
        { name: 'server1', host: 'host1.com', username: 'user1', auth_type: 'password' },
        { name: 'server2', host: 'host2.com', username: 'user2', auth_type: 'key' }
      ]);

      expect(db.inTransaction).toBe(false);
    });
  });

  describe('Helper Functions', () => {
    it('should create test connection with defaults', () => {
      const db = createMockDb();
      const connection = createTestConnection(db);
      
      expect(connection.name).toBe('test-server');
      expect(connection.host).toBe('test.example.com');
      expect(connection.port).toBe(22);
    });

    it('should create test session', () => {
      const db = createMockDb();
      const connection = createTestConnection(db);
      const session = createTestSession(db, connection.id);
      
      expect(session.id).toBeDefined();
      expect(session.connection_id).toBe(connection.id);
      expect(session.session_id).toBeDefined();
    });

    it('should setup test password', async () => {
      const keychain = createMockKeychain();
      
      await setupTestPassword(keychain, 'test-service', 'test-account', 'password123');
      
      const password = await keychain.getPassword('test-service', 'test-account');
      expect(password).toBe('password123');
    });
  });
});
