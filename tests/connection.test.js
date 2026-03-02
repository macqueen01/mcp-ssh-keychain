import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';

const mockOn = vi.fn();
const mockConnect = vi.fn();
const mockEnd = vi.fn();
const mockExec = vi.fn();
const mockSftp = vi.fn();
const mockShell = vi.fn();

vi.mock('../src/keychain.js', () => ({
  getCredential: vi.fn()
}));

vi.mock('ssh2', () => {
  return {
    Client: vi.fn(function() {
      this.connect = mockConnect;
      this.end = mockEnd;
      this.exec = mockExec;
      this.sftp = mockSftp;
      this.shell = mockShell;
      this.on = mockOn;
      this.destroyed = false;
    })
  };
});

vi.mock('../src/logger.js', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    debug: vi.fn(),
    error: vi.fn()
  }
}));

import SSHManager from '../src/ssh-manager.js';
import { getConnection, closeConnection, closeAllConnections, listConnections } from '../src/connection-pool.js';
import { getCredential } from '../src/keychain.js';
import { Client } from 'ssh2';

describe('SSHManager', () => {
  let manager;

  beforeEach(() => {
    vi.clearAllMocks();
    mockOn.mockReturnValue(undefined);
    manager = new SSHManager();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('connect', () => {
    it('should connect with keychain credentials', async () => {
      getCredential.mockResolvedValue('test-password');
      
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      await manager.connect('example.com', 'testuser', 22);

      expect(getCredential).toHaveBeenCalledWith('testuser', 'example.com', 22);
      expect(mockConnect).toHaveBeenCalledWith(
        expect.objectContaining({
          host: 'example.com',
          port: 22,
          username: 'testuser',
          password: 'test-password',
          keepaliveInterval: 30000,
          keepaliveCountMax: 3,
          readyTimeout: 20000,
          tryKeyboard: true
        })
      );
      expect(manager.connected).toBe(true);
    });

    it('should throw error when no credentials stored', async () => {
      getCredential.mockResolvedValue(null);

      await expect(
        manager.connect('example.com', 'testuser', 22)
      ).rejects.toThrow('No credentials stored for testuser@example.com:22. Run ssh_store_password first.');
    });

    it('should use default port 22', async () => {
      getCredential.mockResolvedValue('test-password');
      
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      await manager.connect('example.com', 'testuser');

      expect(getCredential).toHaveBeenCalledWith('testuser', 'example.com', 22);
      expect(mockConnect).toHaveBeenCalledWith(
        expect.objectContaining({
          port: 22
        })
      );
    });

    it('should translate "No response from server" errors', async () => {
      getCredential.mockResolvedValue('test-password');
      
      mockOn.mockImplementation((event, callback) => {
        if (event === 'error') {
          setImmediate(() => callback(new Error('No response from server')));
        }
      });

      await expect(
        manager.connect('example.com', 'testuser', 22)
      ).rejects.toThrow('Connection to testuser@example.com:22 lost during operation');
    });

    it('should handle keyboard-interactive authentication', async () => {
      getCredential.mockResolvedValue('test-password');
      
      let keyboardHandler;
      mockOn.mockImplementation((event, callback) => {
        if (event === 'keyboard-interactive') {
          keyboardHandler = callback;
        }
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      await manager.connect('example.com', 'testuser', 22);

      expect(keyboardHandler).toBeDefined();
      
      const mockFinish = vi.fn();
      keyboardHandler('', '', '', [], mockFinish);
      expect(mockFinish).toHaveBeenCalledWith(['test-password']);
    });
  });

  describe('exec', () => {
    beforeEach(async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });
      await manager.connect('example.com', 'testuser', 22);
    });

    it('should execute command and return output', async () => {
      const mockStream = {
        on: vi.fn((event, callback) => {
          if (event === 'data') {
            process.nextTick(() => callback(Buffer.from('test output')));
          }
          if (event === 'close') {
            setTimeout(() => callback(0), 10);
          }
          return mockStream;
        }),
        stderr: {
          on: vi.fn((event, callback) => {
            if (event === 'data') {
              process.nextTick(() => callback(Buffer.from('')));
            }
            return mockStream.stderr;
          })
        }
      };

      mockExec.mockImplementation((cmd, callback) => {
        callback(null, mockStream);
      });

      const result = await manager.exec('ls -la');

      expect(result).toEqual({
        stdout: 'test output',
        stderr: '',
        code: 0,
        signal: undefined
      });
    });

    it('should throw error when not connected', async () => {
      manager.connected = false;

      await expect(manager.exec('ls')).rejects.toThrow('Not connected to SSH server');
    });
  });

  describe('disconnect', () => {
    it('should close client connection', async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });
      await manager.connect('example.com', 'testuser', 22);

      manager.disconnect();

      expect(mockEnd).toHaveBeenCalled();
      expect(manager.connected).toBe(false);
    });
  });

  describe('getConnectionInfo', () => {
    it('should return connection information', async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });
      await manager.connect('example.com', 'testuser', 2222);

      const info = manager.getConnectionInfo();

      expect(info).toEqual({
        host: 'example.com',
        user: 'testuser',
        port: 2222,
        connected: true
      });
    });
  });
});

describe('Connection Pool', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(async () => {
    await closeAllConnections();
    vi.restoreAllMocks();
  });

  describe('getConnection', () => {
    it('should create new connection', async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      const conn = await getConnection('example.com', 'testuser', 22);

      expect(conn).toBeInstanceOf(SSHManager);
      expect(conn.connected).toBe(true);
    });

    it('should reuse existing connection', async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      const conn1 = await getConnection('example.com', 'testuser', 22);
      const conn2 = await getConnection('example.com', 'testuser', 22);

      expect(conn1).toBe(conn2);
      expect(getCredential).toHaveBeenCalledTimes(1);
    });
  });

  describe('listConnections', () => {
    it('should list all active connections', async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      await getConnection('host1.com', 'user1', 22);
      await getConnection('host2.com', 'user2', 2222);

      const list = listConnections();

      expect(list).toHaveLength(2);
      expect(list).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            key: 'user1@host1.com:22',
            host: 'host1.com',
            user: 'user1',
            port: 22
          }),
          expect.objectContaining({
            key: 'user2@host2.com:2222',
            host: 'host2.com',
            user: 'user2',
            port: 2222
          })
        ])
      );
    });
  });

  describe('closeConnection', () => {
    it('should close specific connection', async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      await getConnection('example.com', 'testuser', 22);
      
      const result = await closeConnection('example.com', 'testuser', 22);

      expect(result).toBe(true);
      expect(listConnections()).toHaveLength(0);
    });

    it('should return false for non-existent connection', async () => {
      const result = await closeConnection('example.com', 'testuser', 22);

      expect(result).toBe(false);
    });
  });

  describe('closeAllConnections', () => {
    it('should close all connections', async () => {
      getCredential.mockResolvedValue('test-password');
      mockOn.mockImplementation((event, callback) => {
        if (event === 'ready') {
          setImmediate(() => callback());
        }
      });

      await getConnection('host1.com', 'user1', 22);
      await getConnection('host2.com', 'user2', 22);

      const count = await closeAllConnections();

      expect(count).toBe(2);
      expect(listConnections()).toHaveLength(0);
    });
  });
});
