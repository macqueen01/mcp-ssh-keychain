/**
 * HTTP/WebSocket Transport for MCP Server
 * Allows Flutter and other HTTP clients to communicate with the MCP server
 */

import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { EventEmitter } from 'events';

/**
 * HTTP Transport for MCP - implements the Transport interface
 */
export class HttpServerTransport extends EventEmitter {
  constructor(options = {}) {
    super();
    this.port = options.port || 3000;
    this.host = options.host || '0.0.0.0';
    this.server = null;
    this.wss = null;
    this.clients = new Map();
    this.clientId = 0;
    this._started = false;
  }

  async start() {
    if (this._started) return;

    return new Promise((resolve, reject) => {
      // Create HTTP server
      this.server = createServer((req, res) => {
        // CORS headers
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

        if (req.method === 'OPTIONS') {
          res.writeHead(204);
          res.end();
          return;
        }

        // Health check endpoint
        if (req.method === 'GET' && req.url === '/health') {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            status: 'ok',
            clients: this.clients.size,
            transport: 'http-websocket'
          }));
          return;
        }

        // Info endpoint
        if (req.method === 'GET' && req.url === '/') {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            name: 'MCP SSH Manager',
            version: '3.1.0',
            transport: 'HTTP/WebSocket',
            websocket: `ws://${this.host}:${this.port}/mcp`
          }));
          return;
        }

        res.writeHead(404);
        res.end('Not Found');
      });

      // Create WebSocket server
      this.wss = new WebSocketServer({
        server: this.server,
        path: '/mcp'
      });

      this.wss.on('connection', (ws, req) => {
        const id = ++this.clientId;
        this.clients.set(id, ws);

        console.error(`[HTTP Transport] Client ${id} connected from ${req.socket.remoteAddress}`);

        ws.on('message', (data) => {
          try {
            const message = JSON.parse(data.toString());
            // Log more details for tools/call
            if (message.method === 'tools/call' && message.params) {
              console.error(`[HTTP Transport] Client ${id} tools/call: ${message.params.name} (id: ${message.id})`);
              if (message.params.arguments) {
                console.error(`[HTTP Transport]   args: ${JSON.stringify(message.params.arguments).substring(0, 200)}`);
              }
            } else {
              console.error(`[HTTP Transport] Client ${id} message: ${message.method || 'response'} ${message.id || ''}`);
            }
            // Emit message for MCP server to handle
            this.emit('message', message, id);
          } catch (err) {
            console.error(`[HTTP Transport] Invalid JSON from client ${id}:`, err.message);
            ws.send(JSON.stringify({
              jsonrpc: '2.0',
              error: { code: -32700, message: 'Parse error' },
              id: null
            }));
          }
        });

        ws.on('close', () => {
          console.error(`[HTTP Transport] Client ${id} disconnected`);
          this.clients.delete(id);
          this.emit('clientDisconnected', id);
        });

        ws.on('error', (err) => {
          console.error(`[HTTP Transport] Client ${id} error:`, err.message);
          this.clients.delete(id);
        });

        // Notify that a new client connected
        this.emit('clientConnected', id);
      });

      this.server.on('error', (err) => {
        reject(err);
      });

      this.server.listen(this.port, this.host, () => {
        this._started = true;
        console.error(`[HTTP Transport] MCP Server listening on http://${this.host}:${this.port}`);
        console.error(`[HTTP Transport] WebSocket endpoint: ws://${this.host}:${this.port}/mcp`);
        resolve();
      });
    });
  }

  /**
   * Send a message to a specific client or broadcast to all
   */
  send(message, clientId = null) {
    const data = JSON.stringify(message);
    console.error(`[HTTP Transport] Sending response to client ${clientId}: id=${message.id}, size=${data.length} bytes`);

    if (clientId !== null) {
      const ws = this.clients.get(clientId);
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(data);
        console.error(`[HTTP Transport] Response sent successfully`);
      } else {
        console.error(`[HTTP Transport] Client ${clientId} not found or not ready (ws=${ws ? 'exists' : 'null'}, state=${ws?.readyState})`);
      }
    } else {
      // Broadcast to all clients
      for (const [id, ws] of this.clients) {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(data);
        }
      }
    }
  }

  /**
   * Close the transport
   */
  async close() {
    // Close all client connections
    for (const [id, ws] of this.clients) {
      ws.close();
    }
    this.clients.clear();

    // Close WebSocket server
    if (this.wss) {
      this.wss.close();
    }

    // Close HTTP server
    if (this.server) {
      return new Promise((resolve) => {
        this.server.close(() => {
          this._started = false;
          resolve();
        });
      });
    }
  }
}

/**
 * MCP Server wrapper that handles HTTP transport
 */
export class McpHttpServer {
  constructor(mcpServer, transport) {
    this.mcpServer = mcpServer;
    this.transport = transport;
    this.pendingRequests = new Map();
  }

  async start() {
    await this.transport.start();

    // Handle incoming messages
    this.transport.on('message', async (message, clientId) => {
      try {
        // Process MCP request
        const response = await this.handleMcpMessage(message);
        if (response) {
          this.transport.send(response, clientId);
        }
      } catch (err) {
        console.error('[MCP HTTP] Error handling message:', err);
        this.transport.send({
          jsonrpc: '2.0',
          error: { code: -32603, message: err.message },
          id: message.id || null
        }, clientId);
      }
    });
  }

  async handleMcpMessage(message) {
    // MCP uses JSON-RPC 2.0
    const { method, params, id } = message;

    // Handle different MCP methods
    switch (method) {
      case 'initialize':
        return {
          jsonrpc: '2.0',
          result: {
            protocolVersion: '2024-11-05',
            capabilities: {
              tools: {}
            },
            serverInfo: {
              name: 'mcp-ssh-manager',
              version: '3.1.0'
            }
          },
          id
        };

      case 'tools/list':
        const tools = await this.mcpServer.listTools();
        return {
          jsonrpc: '2.0',
          result: { tools },
          id
        };

      case 'tools/call':
        const { name, arguments: args } = params;
        try {
          const result = await this.mcpServer.callTool(name, args);
          return {
            jsonrpc: '2.0',
            result,
            id
          };
        } catch (err) {
          return {
            jsonrpc: '2.0',
            error: { code: -32000, message: err.message },
            id
          };
        }

      case 'notifications/initialized':
        // Client notification, no response needed
        return null;

      default:
        return {
          jsonrpc: '2.0',
          error: { code: -32601, message: `Method not found: ${method}` },
          id
        };
    }
  }

  async close() {
    await this.transport.close();
  }
}

export default HttpServerTransport;
