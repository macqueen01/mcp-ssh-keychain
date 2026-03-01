#!/usr/bin/env node

import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { logger } from './logger.js';

// Connection pool (will be populated by connection-pool.js in Task 5)
const connections = new Map();

// MCP Server initialization
const server = new McpServer({
  name: 'mcp-ssh-keychain',
  version: '1.0.0'
}, {
  capabilities: {
    tools: {}
  }
});

// Tool handlers will be registered here in later tasks (Tasks 4-9)

// Graceful shutdown
process.on('SIGINT', async () => {
  logger.info('Shutting down MCP SSH Keychain server...');
  // Close all SSH connections (will be implemented in Task 5)
  // Close SQLite database (will be implemented in Task 3)
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('Shutting down MCP SSH Keychain server...');
  // Close all SSH connections (will be implemented in Task 5)
  // Close SQLite database (will be implemented in Task 3)
  process.exit(0);
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  logger.info('MCP SSH Keychain server started');
}

main().catch((error) => {
  logger.error('Fatal error:', error);
  process.exit(1);
});
