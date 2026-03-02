import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

const EXPECTED_TOOLS = [
  'ssh_store_password',
  'ssh_delete_password',
  'ssh_list_credentials',
  'ssh_execute',
  'ssh_upload',
  'ssh_download',
  'ssh_deploy',
  'ssh_session_start',
  'ssh_session_send',
  'ssh_session_list',
  'ssh_session_close',
  'ssh_tunnel_create',
  'ssh_tunnel_list',
  'ssh_tunnel_close',
  'ssh_connection_status',
  'ssh_close_connection',
  'ssh_close_all_connections',
  'ssh_history',
];

function sendJsonRpc(proc, method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = Date.now();
    const message = JSON.stringify({
      jsonrpc: '2.0',
      id,
      method,
      params,
    });

    let responseData = '';
    let errorData = '';

    const onData = (data) => {
      responseData += data.toString();
      const lines = responseData.split('\n');
      
      for (let i = 0; i < lines.length - 1; i++) {
        const line = lines[i].trim();
        if (line) {
          try {
            const response = JSON.parse(line);
            if (response.id === id) {
              proc.stdout.off('data', onData);
              proc.stderr.off('data', onError);
              resolve(response);
              return;
            }
          } catch (e) {
          }
        }
      }
      responseData = lines[lines.length - 1];
    };

    const onError = (data) => {
      errorData += data.toString();
    };

    proc.stdout.on('data', onData);
    proc.stderr.on('data', onError);

    proc.stdin.write(message + '\n');

    setTimeout(() => {
      proc.stdout.off('data', onData);
      proc.stderr.off('data', onError);
      reject(new Error(`Timeout waiting for response. stderr: ${errorData}`));
    }, 5000);
  });
}

describe('MCP Server Integration', () => {
  let mcpProcess;

  beforeAll(async () => {
    mcpProcess = spawn('node', [join(projectRoot, 'src/index.js')], {
      stdio: ['pipe', 'pipe', 'pipe'],
      cwd: projectRoot,
    });

    await new Promise((resolve) => setTimeout(resolve, 500));
  });

  afterAll(() => {
    if (mcpProcess) {
      mcpProcess.kill();
    }
  });

  it('should respond to initialize', async () => {
    const response = await sendJsonRpc(mcpProcess, 'initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: {
        name: 'test-client',
        version: '1.0.0',
      },
    });

    expect(response.result).toBeDefined();
    expect(response.result.protocolVersion).toBe('2024-11-05');
    expect(response.result.serverInfo.name).toBe('mcp-ssh-keychain');
    expect(response.result.capabilities.tools).toBeDefined();
  });

  it('should respond to tools/list with 18 tools', async () => {
    const response = await sendJsonRpc(mcpProcess, 'tools/list');

    expect(response.result).toBeDefined();
    expect(response.result.tools).toBeDefined();
    expect(response.result.tools).toHaveLength(18);
  });

  it('should include all expected tool names', async () => {
    const response = await sendJsonRpc(mcpProcess, 'tools/list');

    const toolNames = response.result.tools.map((t) => t.name);
    
    for (const expectedTool of EXPECTED_TOOLS) {
      expect(toolNames).toContain(expectedTool);
    }
  });

  it('should have valid tool definitions', async () => {
    const response = await sendJsonRpc(mcpProcess, 'tools/list');

    for (const tool of response.result.tools) {
      expect(tool.name).toBeDefined();
      expect(typeof tool.name).toBe('string');
      expect(tool.description).toBeDefined();
      expect(typeof tool.description).toBe('string');
      expect(tool.inputSchema).toBeDefined();
      expect(tool.inputSchema.type).toBe('object');
      expect(tool.inputSchema.properties).toBeDefined();
    }
  });

  it('should respond to tools/call with ssh_list_credentials', async () => {
    const response = await sendJsonRpc(mcpProcess, 'tools/call', {
      name: 'ssh_list_credentials',
      arguments: {},
    });

    expect(response.result).toBeDefined();
    expect(response.result.content).toBeDefined();
    expect(Array.isArray(response.result.content)).toBe(true);
    expect(response.result.content[0].type).toBe('text');
  });

  it('should handle unknown tool gracefully', async () => {
    const response = await sendJsonRpc(mcpProcess, 'tools/call', {
      name: 'unknown_tool',
      arguments: {},
    });

    expect(response.result).toBeDefined();
    expect(response.result.content[0].text).toContain('Error');
    expect(response.result.isError).toBe(true);
  });
});
