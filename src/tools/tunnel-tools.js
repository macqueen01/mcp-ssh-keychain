import { createTunnel, listTunnels, closeTunnel } from '../tunnel-manager.js';

export const tunnelTools = {
  ssh_tunnel_create: {
    description: 'Create SSH tunnel for port forwarding. Supports local forwarding (access remote service locally) and remote forwarding (expose local service to remote).',
    inputSchema: {
      type: 'object',
      properties: {
        host: {
          type: 'string',
          description: 'SSH server hostname or IP address'
        },
        user: {
          type: 'string',
          description: 'SSH username'
        },
        port: {
          type: 'number',
          description: 'SSH port (default: 22)',
          default: 22
        },
        type: {
          type: 'string',
          enum: ['local', 'remote'],
          description: 'Tunnel type: "local" (access remote service locally) or "remote" (expose local service to remote)'
        },
        localHost: {
          type: 'string',
          description: 'Local bind address (default: 127.0.0.1)',
          default: '127.0.0.1'
        },
        localPort: {
          type: 'number',
          description: 'Local port to bind'
        },
        remoteHost: {
          type: 'string',
          description: 'Remote host to forward to/from'
        },
        remotePort: {
          type: 'number',
          description: 'Remote port to forward to/from'
        }
      },
      required: ['host', 'user', 'type', 'localPort', 'remoteHost', 'remotePort']
    },
    handler: async (params) => {
      const { host, user, port = 22, type, localHost, localPort, remoteHost, remotePort } = params;

      try {
        const tunnel = await createTunnel(host, user, port, {
          type,
          localHost,
          localPort,
          remoteHost,
          remotePort
        });

        return {
          success: true,
          tunnelId: tunnel.id,
          type: tunnel.type,
          local: `${tunnel.config.localHost}:${tunnel.config.localPort}`,
          remote: `${tunnel.config.remoteHost}:${tunnel.config.remotePort}`,
          state: tunnel.state,
          message: `Tunnel created successfully: ${type === 'local' ? 
            `localhost:${localPort} -> ${remoteHost}:${remotePort}` : 
            `${remoteHost}:${remotePort} -> localhost:${localPort}`}`
        };
      } catch (error) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_tunnel_list: {
    description: 'List all active SSH tunnels with their status and statistics.',
    inputSchema: {
      type: 'object',
      properties: {
        server: {
          type: 'string',
          description: 'Optional: filter by server name (user@host:port)'
        }
      }
    },
    handler: async (params) => {
      const { server } = params;

      try {
        const tunnels = listTunnels(server);

        return {
          success: true,
          count: tunnels.length,
          tunnels: tunnels.map(t => ({
            id: t.id,
            server: t.server,
            type: t.type,
            state: t.state,
            local: `${t.config.localHost}:${t.config.localPort}`,
            remote: `${t.config.remoteHost}:${t.config.remotePort}`,
            created: t.created,
            lastActivity: t.lastActivity,
            activeConnections: t.activeConnections,
            stats: {
              bytesTransferred: t.stats.bytesTransferred,
              connectionsTotal: t.stats.connectionsTotal,
              connectionsActive: t.stats.connectionsActive,
              errors: t.stats.errors
            }
          }))
        };
      } catch (error) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_tunnel_close: {
    description: 'Close an active SSH tunnel by its tunnel ID.',
    inputSchema: {
      type: 'object',
      properties: {
        tunnelId: {
          type: 'string',
          description: 'Tunnel ID to close'
        }
      },
      required: ['tunnelId']
    },
    handler: async (params) => {
      const { tunnelId } = params;

      try {
        closeTunnel(tunnelId);

        return {
          success: true,
          message: `Tunnel ${tunnelId} closed successfully`
        };
      } catch (error) {
        return {
          success: false,
          error: error.message
        };
      }
    }
  }
};
