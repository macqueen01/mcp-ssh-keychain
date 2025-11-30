#!/usr/bin/env node

/**
 * Test suite for HTTP/WebSocket MCP Server
 */

import { spawn } from 'child_process';
import WebSocket from 'ws';
import http from 'http';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const TEST_PORT = 3999;
let serverProcess = null;
let testsPassed = 0;
let testsFailed = 0;

function log(message, type = 'info') {
  const colors = {
    info: '\x1b[36m',
    success: '\x1b[32m',
    error: '\x1b[31m',
    reset: '\x1b[0m'
  };
  console.log(`${colors[type]}${message}${colors.reset}`);
}

function assert(condition, message) {
  if (condition) {
    testsPassed++;
    log(`  ✓ ${message}`, 'success');
  } else {
    testsFailed++;
    log(`  ✗ ${message}`, 'error');
  }
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function startServer() {
  return new Promise((resolve, reject) => {
    const serverPath = path.join(__dirname, '..', 'src', 'server-http.js');
    serverProcess = spawn('node', [serverPath, '--port', TEST_PORT.toString()], {
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env }
    });

    let started = false;

    serverProcess.stderr.on('data', (data) => {
      const output = data.toString();
      if (output.includes('listening') && !started) {
        started = true;
        resolve();
      }
    });

    serverProcess.on('error', reject);

    // Timeout after 10 seconds
    setTimeout(() => {
      if (!started) {
        reject(new Error('Server failed to start within 10 seconds'));
      }
    }, 10000);
  });
}

function stopServer() {
  if (serverProcess) {
    serverProcess.kill('SIGTERM');
    serverProcess = null;
  }
}

async function testHealthEndpoint() {
  log('\n[Test] Health Endpoint');

  return new Promise((resolve) => {
    const req = http.request({
      hostname: 'localhost',
      port: TEST_PORT,
      path: '/health',
      method: 'GET'
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        assert(res.statusCode === 200, 'Health endpoint returns 200');
        try {
          const json = JSON.parse(data);
          assert(json.status === 'ok', 'Health status is ok');
          assert(json.transport === 'http-websocket', 'Transport type is correct');
        } catch (e) {
          assert(false, 'Health endpoint returns valid JSON');
        }
        resolve();
      });
    });

    req.on('error', (e) => {
      assert(false, `Health endpoint accessible: ${e.message}`);
      resolve();
    });

    req.end();
  });
}

async function testInfoEndpoint() {
  log('\n[Test] Info Endpoint');

  return new Promise((resolve) => {
    const req = http.request({
      hostname: 'localhost',
      port: TEST_PORT,
      path: '/',
      method: 'GET'
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        assert(res.statusCode === 200, 'Info endpoint returns 200');
        try {
          const json = JSON.parse(data);
          assert(json.name === 'MCP SSH Manager', 'Server name is correct');
          assert(json.websocket.includes('/mcp'), 'WebSocket URL is provided');
        } catch (e) {
          assert(false, 'Info endpoint returns valid JSON');
        }
        resolve();
      });
    });

    req.on('error', (e) => {
      assert(false, `Info endpoint accessible: ${e.message}`);
      resolve();
    });

    req.end();
  });
}

async function testWebSocketConnection() {
  log('\n[Test] WebSocket Connection');

  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/mcp`);
    let connected = false;

    ws.on('open', () => {
      connected = true;
      assert(true, 'WebSocket connection established');
      ws.close();
    });

    ws.on('close', () => {
      if (connected) {
        assert(true, 'WebSocket connection closed cleanly');
      }
      resolve();
    });

    ws.on('error', (e) => {
      assert(false, `WebSocket connection: ${e.message}`);
      resolve();
    });

    setTimeout(() => {
      if (!connected) {
        assert(false, 'WebSocket connection timeout');
        resolve();
      }
    }, 5000);
  });
}

async function testMcpInitialize() {
  log('\n[Test] MCP Initialize');

  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/mcp`);

    ws.on('open', () => {
      // Send initialize request
      ws.send(JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: {
          protocolVersion: '2024-11-05',
          capabilities: {},
          clientInfo: { name: 'test-client', version: '1.0.0' }
        }
      }));
    });

    ws.on('message', (data) => {
      try {
        const response = JSON.parse(data.toString());
        assert(response.jsonrpc === '2.0', 'Response is JSON-RPC 2.0');
        assert(response.id === 1, 'Response ID matches request');
        assert(response.result !== undefined, 'Response has result');
        assert(response.result.protocolVersion !== undefined, 'Protocol version in response');
        assert(response.result.serverInfo !== undefined, 'Server info in response');
        assert(response.result.serverInfo.name === 'mcp-ssh-manager', 'Server name is correct');
      } catch (e) {
        assert(false, `MCP Initialize response valid: ${e.message}`);
      }
      ws.close();
    });

    ws.on('close', () => {
      resolve();
    });

    ws.on('error', (e) => {
      assert(false, `MCP Initialize: ${e.message}`);
      resolve();
    });
  });
}

async function testToolsList() {
  log('\n[Test] MCP Tools List');

  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/mcp`);

    ws.on('open', () => {
      // Send tools/list request
      ws.send(JSON.stringify({
        jsonrpc: '2.0',
        id: 2,
        method: 'tools/list',
        params: {}
      }));
    });

    ws.on('message', (data) => {
      try {
        const response = JSON.parse(data.toString());
        assert(response.id === 2, 'Response ID matches request');
        assert(response.result !== undefined, 'Response has result');
        assert(Array.isArray(response.result.tools), 'Tools is an array');
        assert(response.result.tools.length > 0, 'Tools array is not empty');

        // Check for expected tools
        const toolNames = response.result.tools.map(t => t.name);
        assert(toolNames.includes('ssh_list_servers'), 'Has ssh_list_servers tool');
        assert(toolNames.includes('ssh_execute'), 'Has ssh_execute tool');
        assert(toolNames.includes('ssh_list_files'), 'Has ssh_list_files tool');

        // Check tool structure
        const firstTool = response.result.tools[0];
        assert(firstTool.name !== undefined, 'Tool has name');
        assert(firstTool.description !== undefined, 'Tool has description');
        assert(firstTool.inputSchema !== undefined, 'Tool has inputSchema');
      } catch (e) {
        assert(false, `Tools list response valid: ${e.message}`);
      }
      ws.close();
    });

    ws.on('close', () => {
      resolve();
    });

    ws.on('error', (e) => {
      assert(false, `Tools list: ${e.message}`);
      resolve();
    });
  });
}

async function testListServers() {
  log('\n[Test] MCP List Servers Tool');

  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/mcp`);

    ws.on('open', () => {
      // Call ssh_list_servers tool
      ws.send(JSON.stringify({
        jsonrpc: '2.0',
        id: 3,
        method: 'tools/call',
        params: {
          name: 'ssh_list_servers',
          arguments: {}
        }
      }));
    });

    ws.on('message', (data) => {
      try {
        const response = JSON.parse(data.toString());
        assert(response.id === 3, 'Response ID matches request');

        if (response.error) {
          // It's ok if there's an error (no servers configured)
          assert(true, 'Tool call returned response');
        } else {
          assert(response.result !== undefined, 'Response has result');
          assert(response.result.content !== undefined, 'Result has content');
          assert(Array.isArray(response.result.content), 'Content is array');
        }
      } catch (e) {
        assert(false, `List servers response valid: ${e.message}`);
      }
      ws.close();
    });

    ws.on('close', () => {
      resolve();
    });

    ws.on('error', (e) => {
      assert(false, `List servers: ${e.message}`);
      resolve();
    });
  });
}

async function testInvalidMethod() {
  log('\n[Test] Invalid Method Handling');

  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/mcp`);

    ws.on('open', () => {
      ws.send(JSON.stringify({
        jsonrpc: '2.0',
        id: 4,
        method: 'invalid/method',
        params: {}
      }));
    });

    ws.on('message', (data) => {
      try {
        const response = JSON.parse(data.toString());
        assert(response.id === 4, 'Response ID matches request');
        assert(response.error !== undefined, 'Response has error');
        assert(response.error.code === -32601, 'Error code is method not found');
      } catch (e) {
        assert(false, `Invalid method response: ${e.message}`);
      }
      ws.close();
    });

    ws.on('close', () => {
      resolve();
    });

    ws.on('error', (e) => {
      assert(false, `Invalid method test: ${e.message}`);
      resolve();
    });
  });
}

async function testInvalidJson() {
  log('\n[Test] Invalid JSON Handling');

  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://localhost:${TEST_PORT}/mcp`);

    ws.on('open', () => {
      ws.send('not valid json {{{');
    });

    ws.on('message', (data) => {
      try {
        const response = JSON.parse(data.toString());
        assert(response.error !== undefined, 'Response has error');
        assert(response.error.code === -32700, 'Error code is parse error');
      } catch (e) {
        assert(false, `Invalid JSON response: ${e.message}`);
      }
      ws.close();
    });

    ws.on('close', () => {
      resolve();
    });

    ws.on('error', (e) => {
      assert(false, `Invalid JSON test: ${e.message}`);
      resolve();
    });
  });
}

async function runTests() {
  log('╔════════════════════════════════════════════════════════════╗');
  log('║       MCP HTTP/WebSocket Server Test Suite                 ║');
  log('╚════════════════════════════════════════════════════════════╝');

  try {
    log('\nStarting test server on port ' + TEST_PORT + '...');
    await startServer();
    await sleep(1000); // Give server time to fully initialize
    log('Server started successfully', 'success');

    // Run tests
    await testHealthEndpoint();
    await testInfoEndpoint();
    await testWebSocketConnection();
    await testMcpInitialize();
    await testToolsList();
    await testListServers();
    await testInvalidMethod();
    await testInvalidJson();

  } catch (e) {
    log(`\nTest setup failed: ${e.message}`, 'error');
    testsFailed++;
  } finally {
    stopServer();
  }

  // Summary
  log('\n════════════════════════════════════════════════════════════');
  log(`Tests passed: ${testsPassed}`, testsPassed > 0 ? 'success' : 'info');
  log(`Tests failed: ${testsFailed}`, testsFailed > 0 ? 'error' : 'info');
  log('════════════════════════════════════════════════════════════\n');

  process.exit(testsFailed > 0 ? 1 : 0);
}

runTests();
