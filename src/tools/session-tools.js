import { startSession, sendCommand, listSessions, closeSession } from '../session-manager.js';
import { logger } from '../logger.js';

export const sessionTools = {
  ssh_session_start: {
    description: 'Start a new interactive SSH session with tmux-style command execution. Returns a session ID for subsequent commands.',
    inputSchema: {
      type: 'object',
      properties: {
        host: {
          type: 'string',
          description: 'SSH hostname or IP address'
        },
        user: {
          type: 'string',
          description: 'SSH username'
        },
        port: {
          type: 'number',
          description: 'SSH port (default: 22)',
          default: 22
        }
      },
      required: ['host', 'user']
    },
    handler: async (params) => {
      const { host, user, port = 22 } = params;
      
      try {
        const session = await startSession(host, user, port);
        
        logger.info('ssh_session_start succeeded', { 
          sessionId: session.id, 
          host, 
          user, 
          port 
        });
        
        return {
          success: true,
          sessionId: session.id,
          host: session.host,
          user: session.user,
          port: session.port,
          cwd: session.cwd,
          started: session.createdAt
        };
      } catch (error) {
        logger.error('ssh_session_start failed', { 
          host, 
          user, 
          port, 
          error: error.message 
        });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_session_send: {
    description: 'Send a command to an active SSH session. Uses tmux-style output capture (reads until no new data for 3 seconds).',
    inputSchema: {
      type: 'object',
      properties: {
        sessionId: {
          type: 'string',
          description: 'Session ID from ssh_session_start'
        },
        command: {
          type: 'string',
          description: 'Command to execute in the session'
        }
      },
      required: ['sessionId', 'command']
    },
    handler: async (params) => {
      const { sessionId, command } = params;
      
      try {
        const result = await sendCommand(sessionId, command);
        
        logger.info('ssh_session_send succeeded', { 
          sessionId, 
          command: command.substring(0, 100) 
        });
        
        return {
          success: true,
          sessionId: result.sessionId,
          output: result.output
        };
      } catch (error) {
        logger.error('ssh_session_send failed', { 
          sessionId, 
          command, 
          error: error.message 
        });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_session_list: {
    description: 'List all active SSH sessions with their details (id, host, user, started, lastActivity).',
    inputSchema: {
      type: 'object',
      properties: {}
    },
    handler: async () => {
      try {
        const sessions = listSessions();
        
        logger.info('ssh_session_list succeeded', { 
          count: sessions.length 
        });
        
        return {
          success: true,
          sessions: sessions.map(s => ({
            id: s.id,
            host: s.host,
            user: s.user,
            port: s.port,
            cwd: s.cwd,
            state: s.state,
            started: s.started,
            lastActivity: s.lastActivity
          }))
        };
      } catch (error) {
        logger.error('ssh_session_list failed', { 
          error: error.message 
        });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_session_close: {
    description: 'Close an active SSH session and release its resources.',
    inputSchema: {
      type: 'object',
      properties: {
        sessionId: {
          type: 'string',
          description: 'Session ID to close'
        }
      },
      required: ['sessionId']
    },
    handler: async (params) => {
      const { sessionId } = params;
      
      try {
        const result = closeSession(sessionId);
        
        logger.info('ssh_session_close succeeded', { 
          sessionId 
        });
        
        return {
          success: true,
          sessionId,
          closed: result
        };
      } catch (error) {
        logger.error('ssh_session_close failed', { 
          sessionId, 
          error: error.message 
        });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  }
};
