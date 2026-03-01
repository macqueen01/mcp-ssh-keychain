import { EventEmitter } from 'events';

/**
 * Mock SFTP client for testing file operations
 */
export class MockSFTP extends EventEmitter {
  constructor(options = {}) {
    super();
    this.shouldFail = options.shouldFail || false;
    this.files = new Map();
  }

  fastPut(localPath, remotePath, callback) {
    if (this.shouldFail) {
      callback(new Error('SFTP upload failed'));
    } else {
      this.files.set(remotePath, { localPath, uploaded: true });
      callback(null);
    }
  }

  fastGet(remotePath, localPath, callback) {
    if (this.shouldFail) {
      callback(new Error('SFTP download failed'));
    } else {
      this.files.set(localPath, { remotePath, downloaded: true });
      callback(null);
    }
  }

  end() {
    this.emit('close');
  }
}

/**
 * Mock shell stream for interactive sessions
 */
export class MockShellStream extends EventEmitter {
  constructor(options = {}) {
    super();
    this.shouldFail = options.shouldFail || false;
    this.commands = [];
    this.closed = false;
  }

  write(data) {
    if (this.closed) {
      throw new Error('Stream is closed');
    }
    this.commands.push(data);
    
    // Simulate command output
    if (!this.shouldFail) {
      setImmediate(() => {
        this.emit('data', Buffer.from(`Output for: ${data}\n`));
      });
    }
  }

  end() {
    this.closed = true;
    setImmediate(() => {
      this.emit('close');
    });
  }
}

/**
 * Mock SSH2 Client for testing SSH connections
 */
export class MockClient extends EventEmitter {
  constructor(options = {}) {
    super();
    this.shouldFail = options.shouldFail || false;
    this.connected = false;
    this.execResults = options.execResults || {};
    this.sftpOptions = options.sftpOptions || {};
    this.shellOptions = options.shellOptions || {};
  }

  connect(config) {
    setImmediate(() => {
      if (this.shouldFail) {
        this.emit('error', new Error('Connection failed'));
      } else {
        this.connected = true;
        this.config = config;
        this.emit('ready');
      }
    });
    return this;
  }

  exec(command, callback) {
    if (!this.connected) {
      callback(new Error('Not connected'));
      return;
    }

    const result = this.execResults[command];
    
    if (result && result.error) {
      callback(new Error(result.error));
      return;
    }

    const stream = new EventEmitter();
    
    setImmediate(() => {
      if (result) {
        stream.emit('data', Buffer.from(result.stdout || ''));
        if (result.stderr) {
          stream.stderr = new EventEmitter();
          setImmediate(() => {
            stream.stderr.emit('data', Buffer.from(result.stderr));
          });
        }
        stream.emit('close', result.code || 0, result.signal || null);
      } else {
        // Default success
        stream.emit('data', Buffer.from(''));
        stream.emit('close', 0, null);
      }
    });

    callback(null, stream);
  }

  sftp(callback) {
    if (!this.connected) {
      callback(new Error('Not connected'));
      return;
    }

    setImmediate(() => {
      const sftp = new MockSFTP(this.sftpOptions);
      callback(null, sftp);
    });
  }

  shell(callback) {
    if (!this.connected) {
      callback(new Error('Not connected'));
      return;
    }

    setImmediate(() => {
      const stream = new MockShellStream(this.shellOptions);
      callback(null, stream);
    });
  }

  end() {
    this.connected = false;
    setImmediate(() => {
      this.emit('close');
    });
  }
}

export default MockClient;
