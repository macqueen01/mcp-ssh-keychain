/**
 * Tool Registry
 *
 * Centralized registry of all MCP tools.
 * Imports and merges tool objects from all tool files.
 */

import { keychainTools } from './tools/keychain-tools.js';
import { coreTools } from './tools/core-tools.js';
import { sessionTools } from './tools/session-tools.js';
import { tunnelTools } from './tools/tunnel-tools.js';
import { statusTools } from './tools/status-tools.js';
import { historyTools } from './tools/history-tools.js';

/**
 * Merged tool registry - all 16 tools
 */
const mcpTools = {
  ...keychainTools,
  ...coreTools,
  ...sessionTools,
  ...tunnelTools,
  ...statusTools,
  ...historyTools,
};

/**
 * Get tool definitions for MCP tools/list
 * @returns {Array} Array of tool definitions
 */
export function getToolDefinitions() {
  return Object.entries(mcpTools).map(([name, tool]) => ({
    name,
    description: tool.description,
    inputSchema: tool.inputSchema,
  }));
}

/**
 * Execute a tool by name
 * @param {string} name - Tool name
 * @param {Object} params - Tool parameters
 * @returns {Promise<Object>} Tool execution result
 */
export async function executeTool(name, params) {
  const tool = mcpTools[name];
  if (!tool) {
    throw new Error(`Unknown tool: ${name}`);
  }
  return tool.handler(params);
}
