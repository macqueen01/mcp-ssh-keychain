import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { coreTools } from '../src/tools/core-tools.js';

vi.mock('../src/connection-pool.js', () => ({
  getConnection: vi.fn()
}));

vi.mock('../src/history.js', () => ({
  recordCommand: vi.fn()
}));

vi.mock('../src/logger.js', () => ({
  logger: {
    debug: vi.fn(),
    info: vi.fn(),
    error: vi.fn(),
    warn: vi.fn()
  }
}));

import { getConnection } from '../src/connection-pool.js';
import { recordCommand } from '../src/history.js';

describe('Core SSH Tools', () => {
  let mockConnection;
  let mockSftp;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockSftp = {
      fastPut: vi.fn((local, remote, cb) => cb(null)),
      fastGet: vi.fn((remote, local, cb) => cb(null)),
      chmod: vi.fn((path, mode, cb) => cb(null))
    };

    mockConnection = {
      exec: vi.fn(),
      sftp: vi.fn().mockResolvedValue(mockSftp),
      isConnected: vi.fn().mockReturnValue(true)
    };

    getConnection.mockResolvedValue(mockConnection);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('ssh_execute', () => {
    it('should execute command and record in history on success', async () => {
      mockConnection.exec.mockResolvedValue({
        stdout: 'command output',
        stderr: '',
        code: 0
      });

      const result = await coreTools.ssh_execute.handler({
        host: '10.11.2.7',
        user: 'root',
        port: 22,
        command: 'ls -la',
        timeout: 30000
      });

      expect(result.success).toBe(true);
      expect(result.stdout).toBe('command output');
      expect(result.stderr).toBe('');
      expect(result.exitCode).toBe(0);

      expect(getConnection).toHaveBeenCalledWith('10.11.2.7', 'root', 22);
      expect(mockConnection.exec).toHaveBeenCalledWith('ls -la', { timeout: 30000 });
      
      expect(recordCommand).toHaveBeenCalledWith({
        host: '10.11.2.7',
        user: 'root',
        port: 22,
        command: 'ls -la',
        exit_code: 0,
        stdout: 'command output',
        stderr: '',
        duration_ms: expect.any(Number)
      });
    });

    it('should record failed commands in history', async () => {
      mockConnection.exec.mockRejectedValue(new Error('Connection timeout'));

      const result = await coreTools.ssh_execute.handler({
        host: '10.11.2.7',
        user: 'root',
        command: 'sleep 100'
      });

      expect(result.success).toBe(false);
      expect(result.error).toBe('Connection timeout');

      expect(recordCommand).toHaveBeenCalledWith({
        host: '10.11.2.7',
        user: 'root',
        port: 22,
        command: 'sleep 100',
        exit_code: -1,
        stderr: 'Connection timeout',
        duration_ms: expect.any(Number)
      });
    });

    it('should use default port 22 when not specified', async () => {
      mockConnection.exec.mockResolvedValue({
        stdout: 'ok',
        stderr: '',
        code: 0
      });

      await coreTools.ssh_execute.handler({
        host: 'example.com',
        user: 'admin',
        command: 'whoami'
      });

      expect(getConnection).toHaveBeenCalledWith('example.com', 'admin', 22);
    });
  });

  describe('ssh_upload', () => {
    it('should upload file successfully', async () => {
      const result = await coreTools.ssh_upload.handler({
        host: '10.11.2.7',
        user: 'root',
        port: 22,
        localPath: '/local/file.txt',
        remotePath: '/remote/file.txt'
      });

      expect(result.success).toBe(true);
      expect(result.message).toContain('uploaded successfully');

      expect(getConnection).toHaveBeenCalledWith('10.11.2.7', 'root', 22);
      expect(mockSftp.fastPut).toHaveBeenCalledWith(
        '/local/file.txt',
        '/remote/file.txt',
        expect.any(Function)
      );
    });

    it('should upload file with permissions', async () => {
      const result = await coreTools.ssh_upload.handler({
        host: '10.11.2.7',
        user: 'root',
        localPath: '/local/script.sh',
        remotePath: '/remote/script.sh',
        mode: '0755'
      });

      expect(result.success).toBe(true);
      expect(result.message).toContain('0755');

      expect(mockSftp.fastPut).toHaveBeenCalled();
      expect(mockSftp.chmod).toHaveBeenCalledWith(
        '/remote/script.sh',
        0o755,
        expect.any(Function)
      );
    });

    it('should reject paths with directory traversal', async () => {
      const result = await coreTools.ssh_upload.handler({
        host: '10.11.2.7',
        user: 'root',
        localPath: '/local/file.txt',
        remotePath: '/remote/../etc/passwd'
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain('../');
      expect(mockSftp.fastPut).not.toHaveBeenCalled();
    });

    it('should handle upload failures', async () => {
      mockSftp.fastPut.mockImplementation((local, remote, cb) => {
        cb(new Error('Permission denied'));
      });

      const result = await coreTools.ssh_upload.handler({
        host: '10.11.2.7',
        user: 'root',
        localPath: '/local/file.txt',
        remotePath: '/remote/file.txt'
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain('Permission denied');
    });
  });

  describe('ssh_download', () => {
    it('should download file successfully', async () => {
      const result = await coreTools.ssh_download.handler({
        host: '10.11.2.7',
        user: 'root',
        port: 22,
        remotePath: '/remote/file.txt',
        localPath: '/local/file.txt'
      });

      expect(result.success).toBe(true);
      expect(result.message).toContain('downloaded successfully');

      expect(getConnection).toHaveBeenCalledWith('10.11.2.7', 'root', 22);
      expect(mockSftp.fastGet).toHaveBeenCalledWith(
        '/remote/file.txt',
        '/local/file.txt',
        expect.any(Function)
      );
    });

    it('should reject paths with directory traversal', async () => {
      const result = await coreTools.ssh_download.handler({
        host: '10.11.2.7',
        user: 'root',
        remotePath: '/var/www/../../../etc/passwd',
        localPath: '/local/passwd'
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain('../');
      expect(mockSftp.fastGet).not.toHaveBeenCalled();
    });

    it('should handle download failures', async () => {
      mockSftp.fastGet.mockImplementation((remote, local, cb) => {
        cb(new Error('File not found'));
      });

      const result = await coreTools.ssh_download.handler({
        host: '10.11.2.7',
        user: 'root',
        remotePath: '/remote/missing.txt',
        localPath: '/local/missing.txt'
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain('File not found');
    });
  });

  describe('ssh_deploy', () => {
    it('should deploy file with atomic move and backup', async () => {
      mockConnection.exec
        .mockResolvedValueOnce({ stdout: 'exists\n', stderr: '', code: 0 })
        .mockResolvedValueOnce({ stdout: '', stderr: '', code: 0 })
        .mockResolvedValueOnce({ stdout: '', stderr: '', code: 0 });

      const result = await coreTools.ssh_deploy.handler({
        host: '10.11.2.7',
        user: 'root',
        port: 22,
        localPath: '/local/app.js',
        remotePath: '/var/www/app.js'
      });

      expect(result.success).toBe(true);
      expect(result.message).toContain('deployed successfully');
      expect(result.message).toContain('backed up');
      expect(result.backup).toBe('/var/www/app.js.bak');

      expect(mockSftp.fastPut).toHaveBeenCalledWith(
        '/local/app.js',
        expect.stringMatching(/^\/tmp\/mcp-deploy-/),
        expect.any(Function)
      );

      expect(mockConnection.exec).toHaveBeenCalledWith(
        'test -f /var/www/app.js && echo "exists" || echo "not_exists"'
      );
      expect(mockConnection.exec).toHaveBeenCalledWith(
        'cp /var/www/app.js /var/www/app.js.bak'
      );
      expect(mockConnection.exec).toHaveBeenCalledWith(
        expect.stringMatching(/^mv \/tmp\/mcp-deploy-.*? \/var\/www\/app.js$/)
      );
    });

    it('should deploy new file without backup', async () => {
      mockConnection.exec
        .mockResolvedValueOnce({ stdout: 'not_exists\n', stderr: '', code: 0 })
        .mockResolvedValueOnce({ stdout: '', stderr: '', code: 0 });

      const result = await coreTools.ssh_deploy.handler({
        host: '10.11.2.7',
        user: 'root',
        localPath: '/local/new-file.txt',
        remotePath: '/var/www/new-file.txt'
      });

      expect(result.success).toBe(true);
      expect(result.backup).toBeNull();

      expect(mockConnection.exec).toHaveBeenCalledTimes(2);
      expect(mockConnection.exec).not.toHaveBeenCalledWith(
        expect.stringContaining('cp ')
      );
    });

    it('should deploy with permissions and owner', async () => {
      mockConnection.exec
        .mockResolvedValueOnce({ stdout: 'not_exists\n', stderr: '', code: 0 })
        .mockResolvedValueOnce({ stdout: '', stderr: '', code: 0 })
        .mockResolvedValueOnce({ stdout: '', stderr: '', code: 0 })
        .mockResolvedValueOnce({ stdout: '', stderr: '', code: 0 });

      const result = await coreTools.ssh_deploy.handler({
        host: '10.11.2.7',
        user: 'root',
        localPath: '/local/app.js',
        remotePath: '/var/www/app.js',
        mode: '0644',
        owner: 'www-data:www-data'
      });

      expect(result.success).toBe(true);

      expect(mockConnection.exec).toHaveBeenCalledWith('chmod 0644 /var/www/app.js');
      expect(mockConnection.exec).toHaveBeenCalledWith('chown www-data:www-data /var/www/app.js');
    });

    it('should reject paths with directory traversal', async () => {
      const result = await coreTools.ssh_deploy.handler({
        host: '10.11.2.7',
        user: 'root',
        localPath: '/local/file.txt',
        remotePath: '/var/www/../../../etc/passwd'
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain('../');
      expect(mockSftp.fastPut).not.toHaveBeenCalled();
    });

    it('should handle deployment failures gracefully', async () => {
      mockSftp.fastPut.mockImplementation((local, remote, cb) => {
        cb(new Error('Disk full'));
      });

      const result = await coreTools.ssh_deploy.handler({
        host: '10.11.2.7',
        user: 'root',
        localPath: '/local/app.js',
        remotePath: '/var/www/app.js'
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain('Disk full');
    });
  });
});
