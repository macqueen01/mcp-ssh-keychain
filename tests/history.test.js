import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { recordCommand, queryHistory, getCommandDetail } from '../src/history.js';
import { initializeDatabase, closeDatabase, getDb } from '../src/database.js';

describe('SSH Command History', () => {
  beforeEach(() => {
    initializeDatabase();
    const db = getDb();
    db.exec('DELETE FROM command_history');
  });

  afterEach(() => {
    closeDatabase();
  });

  describe('recordCommand', () => {
    it('should insert command with all fields', () => {
      const record = {
        host: 'prod.example.com',
        user: 'deploy',
        port: 2222,
        command: 'systemctl restart nginx',
        exit_code: 0,
        stdout: 'Service restarted successfully',
        stderr: '',
        duration_ms: 1234,
        session_id: 'sess_abc123'
      };

      const result = recordCommand(record);

      expect(result.changes).toBe(1);
      expect(result.lastInsertRowid).toBeDefined();
    });

    it('should use default port 22 when not specified', () => {
      const record = {
        host: 'test.example.com',
        user: 'admin',
        command: 'ls -la'
      };

      recordCommand(record);

      const db = getDb();
      const saved = db.prepare('SELECT * FROM command_history WHERE host = ?').get('test.example.com');

      expect(saved.port).toBe(22);
    });

    it('should generate unique IDs for each command', () => {
      const record = {
        host: 'test.example.com',
        user: 'admin',
        command: 'pwd'
      };

      recordCommand(record);
      recordCommand(record);

      const db = getDb();
      const all = db.prepare('SELECT id FROM command_history').all();

      expect(all.length).toBe(2);
      expect(all[0].id).not.toBe(all[1].id);
    });

    it('should store timestamp in ISO format', () => {
      const record = {
        host: 'test.example.com',
        user: 'admin',
        command: 'date'
      };

      recordCommand(record);

      const db = getDb();
      const saved = db.prepare('SELECT timestamp FROM command_history').get();

      expect(saved.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
    });

    it('should handle null values for optional fields', () => {
      const record = {
        host: 'test.example.com',
        user: 'admin',
        command: 'echo test'
      };

      recordCommand(record);

      const db = getDb();
      const saved = db.prepare('SELECT * FROM command_history').get();

      expect(saved.exit_code).toBeNull();
      expect(saved.stdout).toBeNull();
      expect(saved.stderr).toBeNull();
      expect(saved.duration_ms).toBeNull();
      expect(saved.session_id).toBeNull();
    });
  });

  describe('queryHistory', () => {
    beforeEach(() => {
      recordCommand({
        host: 'prod.example.com',
        user: 'deploy',
        command: 'systemctl restart nginx',
        exit_code: 0,
        stdout: 'Service restarted',
        stderr: '',
        duration_ms: 1000
      });

      recordCommand({
        host: 'prod.example.com',
        user: 'admin',
        command: 'tail -f /var/log/nginx/error.log',
        exit_code: 0,
        stdout: 'Log output...',
        stderr: '',
        duration_ms: 500
      });

      recordCommand({
        host: 'staging.example.com',
        user: 'deploy',
        command: 'git pull origin main',
        exit_code: 0,
        stdout: 'Already up to date',
        stderr: '',
        duration_ms: 2000
      });
    });

    it('should return all commands when no filters applied', () => {
      const results = queryHistory();

      expect(results.length).toBe(3);
    });

    it('should exclude stdout and stderr in list view', () => {
      const results = queryHistory();

      results.forEach(record => {
        expect(record.stdout).toBeUndefined();
        expect(record.stderr).toBeUndefined();
      });
    });

    it('should include essential fields in list view', () => {
      const results = queryHistory();

      results.forEach(record => {
        expect(record.id).toBeDefined();
        expect(record.timestamp).toBeDefined();
        expect(record.host).toBeDefined();
        expect(record.user).toBeDefined();
        expect(record.command).toBeDefined();
        expect(record).toHaveProperty('exit_code');
        expect(record).toHaveProperty('duration_ms');
      });
    });

    it('should filter by host', () => {
      const results = queryHistory({ host: 'prod.example.com' });

      expect(results.length).toBe(2);
      results.forEach(record => {
        expect(record.host).toBe('prod.example.com');
      });
    });

    it('should filter by user', () => {
      const results = queryHistory({ user: 'deploy' });

      expect(results.length).toBe(2);
      results.forEach(record => {
        expect(record.user).toBe('deploy');
      });
    });

    it('should filter by command pattern', () => {
      const results = queryHistory({ commandFilter: 'nginx' });

      expect(results.length).toBe(2);
      results.forEach(record => {
        expect(record.command.toLowerCase()).toContain('nginx');
      });
    });

    it('should combine multiple filters', () => {
      const results = queryHistory({
        host: 'prod.example.com',
        user: 'deploy'
      });

      expect(results.length).toBe(1);
      expect(results[0].command).toBe('systemctl restart nginx');
    });

    it('should sort by timestamp DESC', () => {
      const results = queryHistory();

      for (let i = 0; i < results.length - 1; i++) {
        const current = new Date(results[i].timestamp);
        const next = new Date(results[i + 1].timestamp);
        expect(current.getTime()).toBeGreaterThanOrEqual(next.getTime());
      }
    });

    it('should respect limit parameter', () => {
      const results = queryHistory({}, 2);

      expect(results.length).toBe(2);
    });

    it('should filter by session_id', () => {
      recordCommand({
        host: 'test.example.com',
        user: 'admin',
        command: 'whoami',
        session_id: 'sess_xyz789'
      });

      const results = queryHistory({ session_id: 'sess_xyz789' });

      expect(results.length).toBe(1);
      expect(results[0].session_id).toBe('sess_xyz789');
    });
  });

  describe('getCommandDetail', () => {
    it('should return full record including stdout/stderr', () => {
      const record = {
        host: 'prod.example.com',
        user: 'deploy',
        command: 'npm install',
        exit_code: 0,
        stdout: 'added 150 packages',
        stderr: 'npm WARN deprecated package@1.0.0',
        duration_ms: 5000
      };

      recordCommand(record);

      const db = getDb();
      const saved = db.prepare('SELECT id FROM command_history').get();
      const detail = getCommandDetail(saved.id);

      expect(detail.stdout).toBe('added 150 packages');
      expect(detail.stderr).toBe('npm WARN deprecated package@1.0.0');
      expect(detail.command).toBe('npm install');
      expect(detail.exit_code).toBe(0);
      expect(detail.duration_ms).toBe(5000);
    });

    it('should return null for non-existent ID', () => {
      const detail = getCommandDetail('nonexistent_id');

      expect(detail).toBeNull();
    });

    it('should return all fields from database', () => {
      const record = {
        host: 'test.example.com',
        user: 'admin',
        port: 2222,
        command: 'ls -la',
        exit_code: 0,
        stdout: 'file1.txt\nfile2.txt',
        stderr: '',
        duration_ms: 100,
        session_id: 'sess_test'
      };

      recordCommand(record);

      const db = getDb();
      const saved = db.prepare('SELECT id FROM command_history').get();
      const detail = getCommandDetail(saved.id);

      expect(detail.id).toBe(saved.id);
      expect(detail.timestamp).toBeDefined();
      expect(detail.host).toBe('test.example.com');
      expect(detail.user).toBe('admin');
      expect(detail.port).toBe(2222);
      expect(detail.command).toBe('ls -la');
      expect(detail.exit_code).toBe(0);
      expect(detail.stdout).toBe('file1.txt\nfile2.txt');
      expect(detail.stderr).toBe('');
      expect(detail.duration_ms).toBe(100);
      expect(detail.session_id).toBe('sess_test');
    });
  });
});
