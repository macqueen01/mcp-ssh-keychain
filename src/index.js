#!/usr/bin/env node

import { createInterface } from 'readline';
import { getToolDefinitions, executeTool } from './tool-registry.js';
import { initializeDatabase, closeDatabase } from './database.js';
import { logger } from './logger.js';

const PROTOCOL_VERSION = '2024-11-05';
const SERVER_NAME = 'mcp-ssh-keychain';
const SERVER_VERSION = '1.0.0';

let initialized = false;

async function handleMessage(message) {
  const { jsonrpc, id, method, params } = message;

  if (jsonrpc !== '2.0') {
    return createError(id, -32600, 'Invalid Request');
  }

  switch (method) {
    case 'initialize':
      return handleInitialize(id, params);

    case 'initialized':
      initialized = true;
      return null;

    case 'tools/list':
      return handleToolsList(id);

    case 'tools/call':
      return handleToolCall(id, params);

    case 'resources/list':
      return handleResourcesList(id);

    case 'prompts/list':
      return handlePromptsList(id);

    default:
      return createError(id, -32601, `Method not found: ${method}`);
  }
}

function handleInitialize(id, params) {
  return {
    jsonrpc: '2.0',
    id,
    result: {
      protocolVersion: PROTOCOL_VERSION,
      capabilities: {
        tools: {},
        resources: {},
        prompts: {},
      },
      serverInfo: {
        name: SERVER_NAME,
        version: SERVER_VERSION,
      },
    },
  };
}

function handleToolsList(id) {
  const tools = getToolDefinitions();
  return {
    jsonrpc: '2.0',
    id,
    result: { tools },
  };
}

async function handleToolCall(id, params) {
  const { name, arguments: args } = params;

  try {
    const result = await executeTool(name, args || {});
    return {
      jsonrpc: '2.0',
      id,
      result: {
        content: [
          {
            type: 'text',
            text: typeof result === 'string' ? result : JSON.stringify(result, null, 2),
          },
        ],
      },
    };
  } catch (error) {
    return {
      jsonrpc: '2.0',
      id,
      result: {
        content: [
          {
            type: 'text',
            text: `Error: ${error.message}`,
          },
        ],
        isError: true,
      },
    };
  }
}

function handleResourcesList(id) {
  return {
    jsonrpc: '2.0',
    id,
    result: { resources: [] },
  };
}

function handlePromptsList(id) {
  return {
    jsonrpc: '2.0',
    id,
    result: { prompts: [] },
  };
}

function createError(id, code, message) {
  return {
    jsonrpc: '2.0',
    id,
    error: { code, message },
  };
}

async function shutdown() {
  logger.info('Shutting down MCP SSH Keychain server...');
  closeDatabase();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

async function main() {
  await initializeDatabase();
  
  const rl = createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false,
  });

  rl.on('line', async (line) => {
    try {
      const message = JSON.parse(line);
      const response = await handleMessage(message);
      if (response) {
        console.log(JSON.stringify(response));
      }
    } catch (error) {
      logger.error('MCP Error:', error);
      console.log(JSON.stringify({
        jsonrpc: '2.0',
        id: null,
        error: {
          code: -32700,
          message: 'Parse error',
        },
      }));
    }
  });

  logger.info('MCP SSH Keychain server started');
}

main().catch((error) => {
  logger.error('Fatal error:', error);
  process.exit(1);
});
