import { Client } from 'ssh2';
import { getCredential } from './keychain.js';
import { logger } from './logger.js';

class SSHManager {
  constructor() {
    this.client = new Client();
    this.connected = false;
    this.sftpClient = null;
    this.cachedHomeDir = null;
    this.host = null;
    this.user = null;
    this.port = null;
  }

  async connect(host, user, port = 22) {
    this.host = host;
    this.user = user;
    this.port = port;

    const password = await getCredential(user, host, port);
    if (!password) {
      throw new Error(`No credentials stored for ${user}@${host}:${port}. Run ssh_store_password first.`);
    }

    return new Promise((resolve, reject) => {
      this.client.on('end', () => {
        this.connected = false;
        logger.warn('Connection ended', { host, user, port });
      });

      this.client.on('close', () => {
        this.connected = false;
        logger.warn('Connection closed', { host, user, port });
      });

      this.client.on('ready', () => {
        this.connected = true;
        logger.info('SSH connection established', { host, user, port });
        resolve();
      });

      this.client.on('error', (err) => {
        this.connected = false;
        if (err.message && err.message.includes('No response from server')) {
          const translatedError = new Error(`Connection to ${user}@${host}:${port} lost during operation`);
          translatedError.originalError = err;
          reject(translatedError);
        } else {
          reject(err);
        }
      });

      this.client.on('keyboard-interactive', (name, instructions, instructionsLang, prompts, finish) => {
        finish([password]);
      });

      const connConfig = {
        host,
        port,
        username: user,
        password,
        keepaliveInterval: 30000,
        keepaliveCountMax: 3,
        readyTimeout: 20000,
        tryKeyboard: true,
        debug: (info) => {
          if (info.includes('Handshake') || info.includes('error')) {
            logger.debug('SSH2 Debug', { info });
          }
        }
      };

      this.client.connect(connConfig);
    });
  }

  async exec(command, options = {}) {
    if (!this.connected) {
      throw new Error('Not connected to SSH server');
    }

    const { timeout = 30000, cwd } = options;
    const fullCommand = cwd ? `cd ${cwd} && ${command}` : command;

    return new Promise((resolve, reject) => {
      let stdout = '';
      let stderr = '';
      let completed = false;
      let stream = null;
      let timeoutId = null;

      if (timeout > 0) {
        timeoutId = setTimeout(() => {
          if (!completed) {
            completed = true;

            if (stream) {
              try {
                stream.write('\x03');
                stream.end();
                stream.destroy();
              } catch (e) {
                // Ignore
              }
            }

            try {
              this.client.end();
              this.connected = false;
            } catch (e) {
              // Ignore
            }

            reject(new Error(`Command timeout after ${timeout}ms: ${command.substring(0, 100)}...`));
          }
        }, timeout);
      }

      this.client.exec(fullCommand, (err, streamObj) => {
        if (err) {
          completed = true;
          if (timeoutId) clearTimeout(timeoutId);
          reject(err);
          return;
        }

        stream = streamObj;

        stream.on('close', (code, signal) => {
          if (!completed) {
            completed = true;
            if (timeoutId) clearTimeout(timeoutId);
            resolve({
              stdout,
              stderr,
              code: code || 0,
              signal
            });
          }
        });

        stream.on('data', (data) => {
          stdout += data.toString();
        });

        stream.stderr.on('data', (data) => {
          stderr += data.toString();
        });

        stream.on('error', (err) => {
          if (!completed) {
            completed = true;
            if (timeoutId) clearTimeout(timeoutId);
            reject(err);
          }
        });
      });
    });
  }

  async shell(options = {}) {
    if (!this.connected) {
      throw new Error('Not connected to SSH server');
    }

    return new Promise((resolve, reject) => {
      this.client.shell(options, (err, stream) => {
        if (err) {
          reject(err);
          return;
        }
        resolve(stream);
      });
    });
  }

  async sftp() {
    if (this.sftpClient) return this.sftpClient;

    return new Promise((resolve, reject) => {
      this.client.sftp((err, sftp) => {
        if (err) {
          reject(err);
          return;
        }
        this.sftpClient = sftp;
        resolve(sftp);
      });
    });
  }

  isConnected() {
    return this.connected && this.client && !this.client.destroyed;
  }

  disconnect() {
    if (this.sftpClient) {
      this.sftpClient.end();
      this.sftpClient = null;
    }
    if (this.client) {
      this.client.end();
      this.connected = false;
    }
  }

  getConnectionInfo() {
    return {
      host: this.host,
      user: this.user,
      port: this.port,
      connected: this.connected
    };
  }
}

export default SSHManager;
