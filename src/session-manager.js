/**
 * SSH Session Manager
 * Manages persistent SSH sessions with state and context
 * Tmux-style interactive sessions with dynamic parameters
 */

import { v4 as uuidv4 } from 'uuid';
import { logger } from './logger.js';
import { getConnection } from './connection-pool.js';

// Map to store active sessions
const sessions = new Map();

// Session states
export const SESSION_STATES = {
  INITIALIZING: 'initializing',
  READY: 'ready',
  BUSY: 'busy',
  ERROR: 'error',
  CLOSED: 'closed'
};

class SSHSession {
  constructor(id, host, user, port, sshManager) {
    this.id = id;
    this.host = host;
    this.user = user;
    this.port = port;
    this.sshManager = sshManager;
    this.state = SESSION_STATES.INITIALIZING;
    this.cwd = null;
    this.createdAt = new Date();
    this.lastActivity = new Date();
    this.shell = null;
    this.outputBuffer = '';
  }

  /**
   * Initialize the session with a shell
   */
  async initialize() {
    try {
      logger.info(`Initializing SSH session ${this.id}`, {
        host: this.host,
        user: this.user,
        port: this.port
      });

      this.shell = await this.sshManager.shell({
        term: 'xterm-256color',
        cols: 80,
        rows: 24
      });
      this.shell.on('data', (data) => {
        this.outputBuffer += data.toString();
        this.lastActivity = new Date();

        // Log output in verbose mode
        if (logger.verbose) {
          logger.debug(`Session ${this.id} output`, {
            data: data.toString().substring(0, 200)
          });
        }
      });

      this.shell.on('close', () => {
        logger.info(`Session ${this.id} shell closed`);
        this.state = SESSION_STATES.CLOSED;
        this.cleanup();
      });

      this.shell.on('error', (err) => {
        logger.error(`Session ${this.id} shell error`, {
          error: err.message
        });
        this.state = SESSION_STATES.ERROR;
      });

      await this.waitForOutput(5000);
      this.outputBuffer = '';

      this.state = SESSION_STATES.READY;

      // Get initial working directory
      await this.updateWorkingDirectory();

      logger.info(`Session ${this.id} initialized`, {
        host: this.host,
        user: this.user,
        cwd: this.cwd
      });

    } catch (error) {
      this.state = SESSION_STATES.ERROR;
      logger.error(`Failed to initialize session ${this.id}`, {
        error: error.message
      });
      throw error;
    }
  }

  /**
   * Wait for output to stabilize (tmux-style: no new data for timeout period)
   */
  async waitForOutput(noDataTimeout = process.env.NODE_ENV === 'test' ? 200 : 3000) {
    const startBufferLength = this.outputBuffer.length;
    let lastBufferLength = startBufferLength;
    let lastChangeTime = Date.now();

    while (true) {
      await new Promise(resolve => setTimeout(resolve, 50));

      const currentLength = this.outputBuffer.length;

      if (currentLength !== lastBufferLength) {
        lastBufferLength = currentLength;
        lastChangeTime = Date.now();
      } else {
        const timeSinceLastChange = Date.now() - lastChangeTime;
        if (timeSinceLastChange >= noDataTimeout) {
          return;
        }
      }
    }
  }

  /**
   * Update working directory
   */
  async updateWorkingDirectory() {
    try {
      const prevBuffer = this.outputBuffer;
      this.shell.write('pwd\n');
      await this.waitForOutput(3000);

      const newOutput = this.outputBuffer.substring(prevBuffer.length);
      const lines = newOutput.split('\n').map(l => l.trim()).filter(l => l && !l.match(/[$#>]\s*$/));
      
      for (const line of lines) {
        if (line.startsWith('/') || line.match(/^[A-Z]:\\/)) {
          this.cwd = line;
          break;
        }
      }

      logger.debug(`Updated working directory for session ${this.id}`, {
        cwd: this.cwd
      });
    } catch (error) {
      logger.warn(`Failed to update working directory for session ${this.id}`, {
        error: error.message
      });
    }
  }

  /**
   * Send a command to the session (tmux-style)
   */
  async sendCommand(command) {
    if (this.state !== SESSION_STATES.READY) {
      throw new Error(`Session ${this.id} is not ready (state: ${this.state})`);
    }

    this.state = SESSION_STATES.BUSY;
    this.lastActivity = new Date();

    try {
      this.outputBuffer = '';

      logger.info(`Session ${this.id} sending command`, {
        command: command.substring(0, 100)
      });

      this.shell.write(command + '\n');
      await this.waitForOutput(3000);

      let output = this.outputBuffer;

      const lines = output.split('\n');
      if (lines.length > 0 && lines[0].includes(command.substring(0, 50))) {
        lines.shift();
      }

      while (lines.length > 0) {
        const lastLine = lines[lines.length - 1].trim();
        if (lastLine.match(/[$#>]\s*$/) || lastLine === '') {
          lines.pop();
        } else {
          break;
        }
      }

      output = lines.join('\n').trim();

      if (command.startsWith('cd ') || command.includes('cd ')) {
        await this.updateWorkingDirectory();
      }

      this.state = SESSION_STATES.READY;

      return {
        output,
        sessionId: this.id
      };

    } catch (error) {
      this.state = SESSION_STATES.ERROR;
      logger.error(`Session ${this.id} command failed`, {
        command,
        error: error.message
      });
      throw error;
    }
  }

  /**
   * Get session info
   */
  getInfo() {
    return {
      id: this.id,
      host: this.host,
      user: this.user,
      port: this.port,
      state: this.state,
      cwd: this.cwd,
      started: this.createdAt,
      lastActivity: this.lastActivity
    };
  }

  /**
   * Close the session
   */
  close() {
    logger.info(`Closing session ${this.id}`);

    if (this.shell) {
      try {
        this.shell.write('exit\n');
        this.shell.end();
      } catch (err) {
        logger.warn(`Error during shell close for session ${this.id}`, {
          error: err.message
        });
      }
      this.shell = null;
    }

    this.state = SESSION_STATES.CLOSED;
    this.cleanup();
  }

  /**
   * Cleanup resources
   */
  cleanup() {
    sessions.delete(this.id);
    this.outputBuffer = '';
  }
}

/**
 * Start a new SSH session with dynamic parameters
 */
export async function startSession(host, user, port = 22) {
  const sessionId = `ssh_${Date.now()}_${uuidv4().substring(0, 8)}`;

  const sshManager = await getConnection(host, user, port);

  const session = new SSHSession(sessionId, host, user, port, sshManager);
  sessions.set(sessionId, session);

  try {
    await session.initialize();

    logger.info('SSH session created', {
      id: sessionId,
      host,
      user,
      port
    });

    return session;
  } catch (error) {
    sessions.delete(sessionId);
    throw error;
  }
}

/**
 * Send a command to an existing session
 */
export async function sendCommand(sessionId, command) {
  const session = sessions.get(sessionId);

  if (!session) {
    throw new Error(`Session ${sessionId} not found`);
  }

  if (session.state === SESSION_STATES.CLOSED) {
    throw new Error(`Session ${sessionId} is closed`);
  }

  return await session.sendCommand(command);
}

/**
 * List all active sessions
 */
export function listSessions() {
  const activeSessions = [];

  for (const [id, session] of sessions.entries()) {
    if (session.state !== SESSION_STATES.CLOSED) {
      activeSessions.push(session.getInfo());
    }
  }

  return activeSessions;
}

/**
 * Close a session
 */
export function closeSession(sessionId) {
  const session = sessions.get(sessionId);

  if (!session) {
    throw new Error(`Session ${sessionId} not found`);
  }

  session.close();
  return true;
}

/**
 * Cleanup old sessions
 */
export function cleanupSessions(maxAge = 30 * 60 * 1000) { // 30 minutes default
  const now = Date.now();
  let cleanedCount = 0;

  for (const [id, session] of sessions.entries()) {
    const age = now - session.lastActivity.getTime();

    if (age > maxAge) {
      logger.info(`Cleaning up inactive session ${id}`, {
        age: Math.floor(age / 1000) + 's'
      });
      session.close();
      cleanedCount++;
    }
  }

  return cleanedCount;
}

// Periodic cleanup of inactive sessions
setInterval(() => {
  const cleaned = cleanupSessions();
  if (cleaned > 0) {
    logger.info(`Cleaned up ${cleaned} inactive sessions`);
  }
}, 5 * 60 * 1000); // Every 5 minutes

export default {
  startSession,
  sendCommand,
  listSessions,
  closeSession,
  cleanupSessions,
  SESSION_STATES
};
