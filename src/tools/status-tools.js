import { listConnections, closeConnection, closeAllConnections } from '../connection-pool.js';

export const statusTools = {
  ssh_connection_status: {
    description: 'List all active SSH connections in the connection pool',
    inputSchema: {
      type: 'object',
      properties: {}
    },
    handler: async () => {
      const connections = listConnections();
      
      return {
        success: true,
        count: connections.length,
        connections: connections.map(conn => ({
          key: conn.key,
          host: conn.host,
          user: conn.user,
          port: conn.port,
          connected: conn.connected
        }))
      };
    }
  },

  ssh_close_connection: {
    description: 'Close a specific SSH connection',
    inputSchema: {
      type: 'object',
      properties: {
        user: {
          type: 'string',
          description: 'SSH username'
        },
        host: {
          type: 'string',
          description: 'SSH hostname or IP address'
        },
        port: {
          type: 'number',
          description: 'SSH port (default: 22)',
          default: 22
        }
      },
      required: ['user', 'host']
    },
    handler: async (params) => {
      const { user, host, port = 22 } = params;
      
      const closed = await closeConnection(host, user, port);
      
      if (closed) {
        return {
          success: true,
          message: `Connection closed for ${user}@${host}:${port}`
        };
      } else {
        return {
          success: false,
          message: `No active connection found for ${user}@${host}:${port}`
        };
      }
    }
  },

  ssh_close_all_connections: {
    description: 'Close all active SSH connections',
    inputSchema: {
      type: 'object',
      properties: {}
    },
    handler: async () => {
      const count = await closeAllConnections();
      
      return {
        success: true,
        message: `Closed ${count} connection(s)`,
        count
      };
    }
  }
};
