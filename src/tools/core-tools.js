import { nanoid } from 'nanoid';
import { getConnection } from '../connection-pool.js';
import { recordCommand } from '../history.js';
import { logger } from '../logger.js';

/**
 * Validate remotePath to prevent directory traversal attacks
 */
function validateRemotePath(remotePath) {
  if (remotePath.includes('../')) {
    throw new Error('Invalid remote path: ../ is not allowed');
  }
}

export const coreTools = {
  ssh_execute: {
    description: 'Execute a command on a remote SSH server. Records command execution in history.',
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
        },
        command: {
          type: 'string',
          description: 'Command to execute on remote server'
        },
        timeout: {
          type: 'number',
          description: 'Command timeout in milliseconds (default: 30000)',
          default: 30000
        }
      },
      required: ['host', 'user', 'command']
    },
    handler: async (params) => {
      const { host, user, port = 22, command, timeout = 30000 } = params;
      
      const startTime = Date.now();
      let result;
      
      try {
        const conn = await getConnection(host, user, port);
        result = await conn.exec(command, { timeout });
        
        const duration = Date.now() - startTime;
        
        recordCommand({
          host,
          user,
          port,
          command,
          exit_code: result.code,
          stdout: result.stdout,
          stderr: result.stderr,
          duration_ms: duration
        });
        
        return {
          success: true,
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.code
        };
      } catch (error) {
        const duration = Date.now() - startTime;
        
        recordCommand({
          host,
          user,
          port,
          command,
          exit_code: -1,
          stderr: error.message,
          duration_ms: duration
        });
        
        logger.error('ssh_execute failed', { host, user, port, error: error.message });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_upload: {
    description: 'Upload a file to a remote SSH server using SFTP. Supports setting file permissions.',
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
        },
        localPath: {
          type: 'string',
          description: 'Local file path to upload'
        },
        remotePath: {
          type: 'string',
          description: 'Remote destination path (no ../ allowed)'
        },
        mode: {
          type: 'string',
          description: 'File permissions in octal format (e.g., "0644", "0755")',
          pattern: '^0[0-7]{3}$'
        }
      },
      required: ['host', 'user', 'localPath', 'remotePath']
    },
    handler: async (params) => {
      const { host, user, port = 22, localPath, remotePath, mode } = params;
      
      try {
        validateRemotePath(remotePath);
        
        const conn = await getConnection(host, user, port);
        const sftp = await conn.sftp();
        
        await new Promise((resolve, reject) => {
          sftp.fastPut(localPath, remotePath, (err) => {
            if (err) reject(err);
            else resolve();
          });
        });
        
        if (mode) {
          const octalMode = parseInt(mode, 8);
          await new Promise((resolve, reject) => {
            sftp.chmod(remotePath, octalMode, (err) => {
              if (err) reject(err);
              else resolve();
            });
          });
        }
        
        logger.info('File uploaded successfully', { host, user, port, localPath, remotePath, mode });
        
        return {
          success: true,
          message: `File uploaded successfully to ${remotePath}${mode ? ` with permissions ${mode}` : ''}`
        };
      } catch (error) {
        logger.error('ssh_upload failed', { host, user, port, localPath, remotePath, error: error.message });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_download: {
    description: 'Download a file from a remote SSH server using SFTP.',
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
        },
        remotePath: {
          type: 'string',
          description: 'Remote file path to download (no ../ allowed)'
        },
        localPath: {
          type: 'string',
          description: 'Local destination path'
        }
      },
      required: ['host', 'user', 'remotePath', 'localPath']
    },
    handler: async (params) => {
      const { host, user, port = 22, remotePath, localPath } = params;
      
      try {
        validateRemotePath(remotePath);
        
        const conn = await getConnection(host, user, port);
        const sftp = await conn.sftp();
        
        await new Promise((resolve, reject) => {
          sftp.fastGet(remotePath, localPath, (err) => {
            if (err) reject(err);
            else resolve();
          });
        });
        
        logger.info('File downloaded successfully', { host, user, port, remotePath, localPath });
        
        return {
          success: true,
          message: `File downloaded successfully to ${localPath}`
        };
      } catch (error) {
        logger.error('ssh_download failed', { host, user, port, remotePath, localPath, error: error.message });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  },

  ssh_deploy: {
    description: 'Deploy a file to a remote server with atomic move and backup. Uploads to temp location, backs up original, then atomically moves to final location.',
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
        },
        localPath: {
          type: 'string',
          description: 'Local file path to deploy'
        },
        remotePath: {
          type: 'string',
          description: 'Remote destination path (no ../ allowed)'
        },
        mode: {
          type: 'string',
          description: 'File permissions in octal format (e.g., "0644", "0755")',
          pattern: '^0[0-7]{3}$'
        },
        owner: {
          type: 'string',
          description: 'File owner in format "user:group" (requires appropriate permissions)'
        }
      },
      required: ['host', 'user', 'localPath', 'remotePath']
    },
    handler: async (params) => {
      const { host, user, port = 22, localPath, remotePath, mode, owner } = params;
      
      try {
        validateRemotePath(remotePath);
        
        const conn = await getConnection(host, user, port);
        const sftp = await conn.sftp();
        
        // Generate temp path
        const tempPath = `/tmp/mcp-deploy-${nanoid()}`;
        
        // Step 1: Upload to temp location
        await new Promise((resolve, reject) => {
          sftp.fastPut(localPath, tempPath, (err) => {
            if (err) reject(err);
            else resolve();
          });
        });
        
        logger.debug('File uploaded to temp location', { tempPath });
        
        // Step 2: Check if original exists and back it up
        const checkExistsResult = await conn.exec(`test -f ${remotePath} && echo "exists" || echo "not_exists"`);
        const fileExists = checkExistsResult.stdout.trim() === 'exists';
        
        if (fileExists) {
          const backupResult = await conn.exec(`cp ${remotePath} ${remotePath}.bak`);
          if (backupResult.code !== 0) {
            throw new Error(`Failed to create backup: ${backupResult.stderr}`);
          }
          logger.debug('Original file backed up', { backup: `${remotePath}.bak` });
        }
        
        // Step 3: Atomic move to final location
        const moveResult = await conn.exec(`mv ${tempPath} ${remotePath}`);
        if (moveResult.code !== 0) {
          throw new Error(`Failed to move file to final location: ${moveResult.stderr}`);
        }
        
        logger.debug('File moved to final location', { remotePath });
        
        // Step 4: Set permissions if specified
        if (mode) {
          const chmodResult = await conn.exec(`chmod ${mode} ${remotePath}`);
          if (chmodResult.code !== 0) {
            throw new Error(`Failed to set permissions: ${chmodResult.stderr}`);
          }
          logger.debug('File permissions set', { mode });
        }
        
        // Step 5: Set owner if specified
        if (owner) {
          const chownResult = await conn.exec(`chown ${owner} ${remotePath}`);
          if (chownResult.code !== 0) {
            throw new Error(`Failed to set owner: ${chownResult.stderr}`);
          }
          logger.debug('File owner set', { owner });
        }
        
        logger.info('File deployed successfully', { host, user, port, localPath, remotePath, mode, owner });
        
        return {
          success: true,
          message: `File deployed successfully to ${remotePath}${fileExists ? ' (original backed up to .bak)' : ''}`,
          backup: fileExists ? `${remotePath}.bak` : null
        };
      } catch (error) {
        logger.error('ssh_deploy failed', { host, user, port, localPath, remotePath, error: error.message });
        
        return {
          success: false,
          error: error.message
        };
      }
    }
  }
};
