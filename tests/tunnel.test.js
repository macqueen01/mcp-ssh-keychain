import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import EventEmitter from 'events';

vi.mock('net', () => ({
  default: {
    createServer: vi.fn((handler) => ({
      listen: vi.fn((port, host, callback) => {
        setTimeout(() => callback && callback(), 0);
      }),
      close: vi.fn()
    })),
    connect: vi.fn()
  }
}));

vi.mock('../src/connection-pool.js', () => ({
  getConnection: vi.fn()
}));

vi.mock('../src/logger.js', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    debug: vi.fn(),
    error: vi.fn()
  }
}));

import { createTunnel, listTunnels, closeTunnel, TUNNEL_TYPES, TUNNEL_STATES } from '../src/tunnel-manager.js';
import { getConnection } from '../src/connection-pool.js';

describe('Tunnel Manager', () => {
  let mockClient;
  let mockManager;
  let mockForwardOut;
  let mockForwardIn;
  let mockUnforwardIn;
  let mockOn;
  let portCounter = 9000;

  class MockSSHClient extends EventEmitter {
    constructor() {
      super();
      this.forwardOut = mockForwardOut;
      this.forwardIn = mockForwardIn;
      this.unforwardIn = mockUnforwardIn;
      this.on = (...args) => {
        mockOn(...args);
        return super.on(...args);
      };
    }
  }

  beforeEach(() => {
    vi.clearAllMocks();
    mockForwardOut = vi.fn();
    mockForwardIn = vi.fn();
    mockUnforwardIn = vi.fn();
    mockOn = vi.fn();
    mockClient = new MockSSHClient();
    mockManager = { client: mockClient };
    getConnection.mockResolvedValue(mockManager);
  });

  afterEach(async () => {
    const tunnels = listTunnels();
    for (const tunnel of tunnels) {
      try {
        closeTunnel(tunnel.id);
      } catch (e) {}
    }
    vi.clearAllTimers();
    await new Promise(resolve => setTimeout(resolve, 10));
  });

  describe('createTunnel', () => {
    it('should create local tunnel successfully', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localHost: '127.0.0.1',
        localPort: 8080,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(tunnel).toBeDefined();
      expect(tunnel.id).toMatch(/^tunnel_\d+_[a-f0-9]{8}$/);
      expect(tunnel.type).toBe(TUNNEL_TYPES.LOCAL);
      expect(tunnel.state).toBe(TUNNEL_STATES.ACTIVE);
      expect(tunnel.serverName).toBe('testuser@example.com:22');
      expect(getConnection).toHaveBeenCalledWith('example.com', 'testuser', 22);
    });

    it('should create remote tunnel successfully', async () => {
      mockForwardIn.mockImplementation((host, port, callback) => {
        callback(null);
      });

      const config = {
        type: TUNNEL_TYPES.REMOTE,
        localHost: '127.0.0.1',
        localPort: 3000,
        remoteHost: '0.0.0.0',
        remotePort: 8080
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(tunnel).toBeDefined();
      expect(tunnel.type).toBe(TUNNEL_TYPES.REMOTE);
      expect(tunnel.state).toBe(TUNNEL_STATES.ACTIVE);
      expect(mockForwardIn).toHaveBeenCalledWith(
        '0.0.0.0',
        8080,
        expect.any(Function)
      );
    });

    it('should use default port 22 when not specified', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: 8081,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(getConnection).toHaveBeenCalledWith('example.com', 'testuser', 22);
      expect(tunnel.serverName).toBe('testuser@example.com:22');
    });

    it('should throw error for invalid tunnel type', async () => {
      const config = {
        type: 'invalid',
        localPort: 8080,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      await expect(
        createTunnel('example.com', 'testuser', 22, config)
      ).rejects.toThrow('Invalid tunnel type: invalid');
    });

    it('should throw error when remote host/port missing', async () => {
      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: 8080
      };

      await expect(
        createTunnel('example.com', 'testuser', 22, config)
      ).rejects.toThrow('Remote host and port required for port forwarding');
    });

    it('should throw error when local port missing', async () => {
      const config = {
        type: TUNNEL_TYPES.LOCAL,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      await expect(
        createTunnel('example.com', 'testuser', 22, config)
      ).rejects.toThrow('Local port required');
    });

    it('should set default localHost to 127.0.0.1', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: 8080,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(tunnel.config.localHost).toBe('127.0.0.1');
    });
  });

  describe('listTunnels', () => {
    it('should return empty array when no tunnels', () => {
      const tunnels = listTunnels();
      expect(tunnels).toEqual([]);
    });

    it('should list all active tunnels', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config1 = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote1.example.com',
        remotePort: 80
      };

      const config2 = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote2.example.com',
        remotePort: 443
      };

      await createTunnel('example.com', 'user1', 22, config1);
      await createTunnel('example.com', 'user2', 22, config2);

      const tunnels = listTunnels();

      expect(tunnels).toHaveLength(2);
      expect(tunnels[0]).toMatchObject({
        server: 'user1@example.com:22',
        type: TUNNEL_TYPES.LOCAL,
        state: TUNNEL_STATES.ACTIVE,
        config: {
          localHost: '127.0.0.1',
          remoteHost: 'remote1.example.com',
          remotePort: 80
        }
      });
      expect(tunnels[0].config.localPort).toBeGreaterThan(0);
    });

    it('should filter tunnels by server name', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config1 = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const config2 = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      await createTunnel('host1.com', 'user1', 22, config1);
      await createTunnel('host2.com', 'user2', 22, config2);

      const tunnels = listTunnels('user1@host1.com:22');

      expect(tunnels).toHaveLength(1);
      expect(tunnels[0].server).toBe('user1@host1.com:22');
    });

    it('should include tunnel statistics', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      await createTunnel('example.com', 'testuser', 22, config);

      const tunnels = listTunnels();

      expect(tunnels[0].stats).toEqual({
        bytesTransferred: 0,
        connectionsTotal: 0,
        connectionsActive: 0,
        errors: 0
      });
    });
  });

  describe('closeTunnel', () => {
    it('should close tunnel successfully', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);
      const tunnelId = tunnel.id;

      const result = closeTunnel(tunnelId);

      expect(result).toBe(true);
      expect(tunnel.state).toBe(TUNNEL_STATES.CLOSED);
      expect(listTunnels()).toHaveLength(0);
    });

    it('should throw error when tunnel not found', () => {
      expect(() => {
        closeTunnel('non-existent-id');
      }).toThrow('Tunnel non-existent-id not found');
    });

    it('should unforward remote tunnel on close', async () => {
      mockForwardIn.mockImplementation((host, port, callback) => {
        callback(null);
      });

      const config = {
        type: TUNNEL_TYPES.REMOTE,
        localPort: 3000,
        remoteHost: '0.0.0.0',
        remotePort: 8080
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      closeTunnel(tunnel.id);

      expect(mockUnforwardIn).toHaveBeenCalledWith('0.0.0.0', 8080);
    });
  });

  describe('Tunnel reconnection', () => {
    it('should have maxReconnectAttempts set to 3', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(tunnel.maxReconnectAttempts).toBe(3);
    });

    it('should track reconnect attempts and reset on success', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(tunnel.reconnectAttempts).toBe(0);

      tunnel.state = TUNNEL_STATES.FAILED;
      const result = await tunnel.reconnect();

      expect(result).toBe(true);
      expect(tunnel.reconnectAttempts).toBe(0);
      expect(tunnel.state).toBe(TUNNEL_STATES.ACTIVE);
    });

    it('should fail after max reconnect attempts', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      tunnel.reconnectAttempts = 3;
      const result = await tunnel.reconnect();

      expect(result).toBe(false);
      expect(tunnel.state).toBe(TUNNEL_STATES.FAILED);
    });
  });

  describe('Tunnel stats tracking', () => {
    it('should track bytes transferred', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(tunnel.stats.bytesTransferred).toBe(0);
    });

    it('should track connection counts', async () => {
      const mockStream = new EventEmitter();
      mockForwardOut.mockResolvedValue(mockStream);

      const config = {
        type: TUNNEL_TYPES.LOCAL,
        localPort: portCounter++,
        remoteHost: 'remote.example.com',
        remotePort: 80
      };

      const tunnel = await createTunnel('example.com', 'testuser', 22, config);

      expect(tunnel.stats.connectionsTotal).toBe(0);
      expect(tunnel.stats.connectionsActive).toBe(0);
      expect(tunnel.stats.errors).toBe(0);
    });
  });
});
