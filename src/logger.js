import fs from 'fs';
import path from 'path';
import { homedir } from 'os';

const DATA_DIR = path.join(homedir(), '.local', 'share', 'mcp-ssh-keychain');
const LOG_FILE = path.join(DATA_DIR, 'debug.log');
const MAX_LOG_SIZE = 10 * 1024 * 1024; // 10MB

export const LOG_LEVELS = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3
};

const COLORS = {
  DEBUG: '\x1b[36m',
  INFO: '\x1b[32m',
  WARN: '\x1b[33m',
  ERROR: '\x1b[31m',
  RESET: '\x1b[0m'
};

const ICONS = {
  DEBUG: '🔍',
  INFO: '✅',
  WARN: '⚠️',
  ERROR: '❌'
};

const PASSWORD_PATTERNS = [
  /password[=:]\s*['"]?([^'"}\s]+)/gi,
  /passwd[=:]\s*['"]?([^'"}\s]+)/gi,
  /pwd[=:]\s*['"]?([^'"}\s]+)/gi,
  /secret[=:]\s*['"]?([^'"}\s]+)/gi,
  /token[=:]\s*['"]?([^'"}\s]+)/gi,
  /apikey[=:]\s*['"]?([^'"}\s]+)/gi,
  /api_key[=:]\s*['"]?([^'"}\s]+)/gi
];

function redactPasswords(text) {
  if (typeof text !== 'string') return text;
  
  let redacted = text;
  for (const pattern of PASSWORD_PATTERNS) {
    redacted = redacted.replace(pattern, (match, captured) => {
      return match.replace(captured, '***REDACTED***');
    });
  }
  return redacted;
}

class Logger {
  constructor() {
    const envLevel = process.env.SSH_LOG_LEVEL?.toUpperCase() || 'INFO';
    this.currentLevel = LOG_LEVELS[envLevel] ?? LOG_LEVELS.INFO;
    this.verbose = process.env.SSH_VERBOSE === 'true';
    
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
    
    this.logFile = LOG_FILE;
    this.rotateLogIfNeeded();
  }
  
  rotateLogIfNeeded() {
    try {
      if (fs.existsSync(this.logFile)) {
        const stats = fs.statSync(this.logFile);
        if (stats.size > MAX_LOG_SIZE) {
          fs.truncateSync(this.logFile, 0);
        }
      }
    } catch (error) {
      // Ignore rotation errors
    }
  }

  formatMessage(level, message, data = {}) {
    const timestamp = new Date().toISOString();
    const levelName = Object.keys(LOG_LEVELS).find(key => LOG_LEVELS[key] === level) || 'INFO';
    
    const redactedMessage = redactPasswords(message);
    
    const consoleFormat = `${COLORS[levelName]}${ICONS[levelName]} [${timestamp}] [${levelName}]${COLORS.RESET} ${redactedMessage}`;
    const fileFormat = `[${timestamp}] [${levelName}] ${redactedMessage}`;
    
    let dataStr = '';
    if (Object.keys(data).length > 0) {
      const redactedData = JSON.stringify(data, (key, value) => {
        if (typeof value === 'string') {
          return redactPasswords(value);
        }
        return value;
      }, 2);
      dataStr = '\n  ' + redactedData.replace(/\n/g, '\n  ');
    }
    
    return {
      console: consoleFormat + (this.verbose && dataStr ? dataStr : ''),
      file: fileFormat + dataStr
    };
  }
  
  log(level, message, data = {}) {
    if (level < this.currentLevel) {
      return;
    }
    
    const formatted = this.formatMessage(level, message, data);
    
    console.error(formatted.console);
    
    try {
      fs.appendFileSync(this.logFile, formatted.file + '\n');
    } catch (error) {
      // Ignore file write errors
    }
  }
  
  debug(message, data) {
    this.log(LOG_LEVELS.DEBUG, message, data);
  }
  
  info(message, data) {
    this.log(LOG_LEVELS.INFO, message, data);
  }
  
  warn(message, data) {
    this.log(LOG_LEVELS.WARN, message, data);
  }
  
  error(message, data) {
    this.log(LOG_LEVELS.ERROR, message, data);
  }

  logCommand(server, command, cwd = null) {
    const logData = {
      server,
      command: this.verbose ? command : command.substring(0, 100) + (command.length > 100 ? '...' : ''),
      cwd
    };

    if (this.verbose) {
      this.debug('Executing SSH command', logData);
    } else {
      this.info(`SSH execute on ${server}`, { command: logData.command });
    }

    return Date.now();
  }

  logCommandResult(server, command, startTime, result) {
    const duration = Date.now() - startTime;

    const resultData = {
      success: !result.code,
      duration: `${duration}ms`,
      error: result.code ? result.stderr : undefined
    };

    if (result.code) {
      this.error(`Command failed on ${server}`, resultData);
    } else if (this.verbose) {
      this.debug(`Command completed on ${server}`, resultData);
    }
  }

  logConnection(server, event, data = {}) {
    const message = `SSH connection ${event}: ${server}`;

    switch (event) {
    case 'established':
      this.info(message, data);
      break;
    case 'reused':
      this.debug(message, data);
      break;
    case 'closed':
      this.info(message, data);
      break;
    case 'failed':
      this.error(message, data);
      break;
    default:
      this.debug(message, data);
    }
  }

  logTransfer(operation, server, source, destination, result = null) {
    const data = { server, source, destination };

    if (result) {
      data.success = result.success;
      data.size = result.size;
      data.duration = result.duration;
    }

    const message = `File ${operation} ${result ? (result.success ? 'completed' : 'failed') : 'started'}`;

    if (result && !result.success) {
      this.error(message, data);
    } else {
      this.info(message, data);
    }
  }
}

export const logger = new Logger();
export const { debug, info, warn, error } = logger;
export default logger;
