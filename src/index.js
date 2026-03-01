#!/usr/bin/env node

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { logger } from './logger.js';
import { closeDatabase } from './database.js';

const connections = new Map();

const server = new McpServer({
  name: 'mcp-ssh-keychain',
  version: '1.0.0'
}, {
  capabilities: {
    tools: {}
  }
});

async function shutdown() {
  logger.info('Shutting down MCP SSH Keychain server...');
  
  for (const [name, conn] of connections.entries()) {
    try {
      await conn.dispose();
      logger.debug(`Closed SSH connection: ${name}`);
    } catch (error) {
      logger.error(`Failed to close SSH connection ${name}:`, { error: error.message });
    }
  }
  connections.clear();
  
  closeDatabase();
  
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  logger.info('MCP SSH Keychain server started');
}

main().catch((error) => {
  logger.error('Fatal error:', error);
  process.exit(1);
});
