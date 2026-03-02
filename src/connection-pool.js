import SSHManager from './ssh-manager.js';
import { logger } from './logger.js';

const connections = new Map();

function formatKey(user, host, port) {
  return `${user}@${host}:${port}`;
}

export async function getConnection(host, user, port = 22) {
  const key = formatKey(user, host, port);
  
  if (connections.has(key)) {
    const conn = connections.get(key);
    if (conn.isConnected()) {
      logger.debug('Reusing existing connection', { host, user, port });
      return conn;
    } else {
      logger.warn('Connection exists but not connected, reconnecting', { host, user, port });
      connections.delete(key);
    }
  }
  
  logger.info('Creating new SSH connection', { host, user, port });
  const manager = new SSHManager();
  
  await manager.connect(host, user, port);
  
  manager.client.on('end', () => {
    logger.warn('Connection ended, removing from pool', { host, user, port });
    connections.delete(key);
  });
  
  manager.client.on('close', () => {
    logger.warn('Connection closed, removing from pool', { host, user, port });
    connections.delete(key);
  });
  
  connections.set(key, manager);
  
  return manager;
}

export async function closeConnection(host, user, port = 22) {
  const key = formatKey(user, host, port);
  
  if (!connections.has(key)) {
    logger.debug('Connection not found in pool', { host, user, port });
    return false;
  }
  
  const conn = connections.get(key);
  try {
    conn.disconnect();
    connections.delete(key);
    logger.info('Connection closed', { host, user, port });
    return true;
  } catch (error) {
    logger.error('Error closing connection', { host, user, port, error: error.message });
    connections.delete(key);
    return false;
  }
}

export async function closeAllConnections() {
  const keys = Array.from(connections.keys());
  let closed = 0;
  
  for (const key of keys) {
    const conn = connections.get(key);
    try {
      conn.disconnect();
      closed++;
    } catch (error) {
      logger.error('Error closing connection', { key, error: error.message });
    }
  }
  
  connections.clear();
  logger.info('All connections closed', { count: closed });
  
  return closed;
}

export function listConnections() {
  const list = [];
  
  for (const [key, conn] of connections.entries()) {
    const info = conn.getConnectionInfo();
    list.push({
      key,
      ...info
    });
  }
  
  return list;
}
