import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { getCredential, storeCredentialOOB, deleteCredential, listCredentials } from '../src/keychain.js';

vi.mock('cross-keychain', () => ({
  getPassword: vi.fn(),
  setPassword: vi.fn(),
  deletePassword: vi.fn()
}));

vi.mock('child_process', () => ({
  execSync: vi.fn()
}));

import { getPassword, setPassword, deletePassword } from 'cross-keychain';
import { execSync } from 'child_process';

describe('Keychain Integration', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('getCredential', () => {
    it('should retrieve password from keychain', async () => {
      getPassword.mockResolvedValue('secret-password');

      const result = await getCredential('root', '10.11.2.7', 22);

      expect(result).toBe('secret-password');
      expect(getPassword).toHaveBeenCalledWith('mcp-ssh-keychain', 'root@10.11.2.7:22');
    });

    it('should return null when credential not found', async () => {
      getPassword.mockRejectedValue(new Error('Password not found'));

      const result = await getCredential('admin', 'example.com', 22);

      expect(result).toBeNull();
    });

    it('should use default port 22 when not specified', async () => {
      getPassword.mockResolvedValue('test-pass');

      await getCredential('user', 'host.example.com');

      expect(getPassword).toHaveBeenCalledWith('mcp-ssh-keychain', 'user@host.example.com:22');
    });
  });

  describe('storeCredentialOOB', () => {
    it('should store password from osascript dialog', async () => {
      execSync.mockReturnValue('button returned:Save, text returned:my-secure-password');
      setPassword.mockResolvedValue();

      const result = await storeCredentialOOB('root', '10.11.2.7', 22);

      expect(result.success).toBe(true);
      expect(setPassword).toHaveBeenCalledWith('mcp-ssh-keychain', 'root@10.11.2.7:22', 'my-secure-password');
      expect(execSync).toHaveBeenCalledWith(
        expect.stringContaining('osascript -e'),
        expect.objectContaining({ encoding: 'utf8' })
      );
    });

    it('should handle user cancellation gracefully', async () => {
      const error = new Error('User canceled');
      error.status = 128;
      execSync.mockImplementation(() => {
        throw error;
      });

      const result = await storeCredentialOOB('user', 'host.com', 22);

      expect(result.success).toBe(false);
      expect(result.error).toContain('cancelled');
      expect(setPassword).not.toHaveBeenCalled();
    });

    it('should reject empty passwords', async () => {
      execSync.mockReturnValue('button returned:Save, text returned:');

      const result = await storeCredentialOOB('user', 'host.com', 22);

      expect(result.success).toBe(false);
      expect(result.error).toContain('empty');
      expect(setPassword).not.toHaveBeenCalled();
    });

    it('should handle osascript parsing errors', async () => {
      execSync.mockReturnValue('invalid response format');

      const result = await storeCredentialOOB('user', 'host.com', 22);

      expect(result.success).toBe(false);
      expect(result.error).toContain('parse');
      expect(setPassword).not.toHaveBeenCalled();
    });

    it('should format account string correctly', async () => {
      execSync.mockReturnValue('button returned:Save, text returned:password123');
      setPassword.mockResolvedValue();

      await storeCredentialOOB('deploy', 'server.example.com', 2222);

      expect(setPassword).toHaveBeenCalledWith('mcp-ssh-keychain', 'deploy@server.example.com:2222', 'password123');
    });

    it('should never expose password in error messages', async () => {
      execSync.mockReturnValue('button returned:Save, text returned:super-secret-password');
      setPassword.mockRejectedValue(new Error('Keychain access denied'));

      const result = await storeCredentialOOB('user', 'host.com', 22);

      expect(result.success).toBe(false);
      expect(result.error).not.toContain('super-secret-password');
      expect(result.error).toContain('Keychain access denied');
    });
  });

  describe('deleteCredential', () => {
    it('should delete credential from keychain', async () => {
      deletePassword.mockResolvedValue();

      const result = await deleteCredential('root', '10.11.2.7', 22);

      expect(result.success).toBe(true);
      expect(deletePassword).toHaveBeenCalledWith('mcp-ssh-keychain', 'root@10.11.2.7:22');
    });

    it('should handle credential not found', async () => {
      deletePassword.mockRejectedValue(new Error('Password not found'));

      const result = await deleteCredential('user', 'host.com', 22);

      expect(result.success).toBe(false);
      expect(result.error).toContain('not found');
    });

    it('should handle keychain errors', async () => {
      deletePassword.mockRejectedValue(new Error('Access denied'));

      const result = await deleteCredential('user', 'host.com', 22);

      expect(result.success).toBe(false);
      expect(result.error).toContain('Access denied');
    });
  });

  describe('listCredentials', () => {
    it('should list all credentials without passwords', async () => {
      const mockOutput = `
        "acct"<blob>="root@10.11.2.7:22"
        "acct"<blob>="admin@server.example.com:2222"
        "acct"<blob>="deploy@staging.example.com:22"
      `;
      execSync.mockReturnValue(mockOutput);

      const result = await listCredentials();

      expect(result).toHaveLength(3);
      expect(result[0]).toEqual({
        account: 'root@10.11.2.7:22',
        user: 'root',
        host: '10.11.2.7',
        port: '22'
      });
      expect(result[1]).toEqual({
        account: 'admin@server.example.com:2222',
        user: 'admin',
        host: 'server.example.com',
        port: '2222'
      });
      expect(result[2]).toEqual({
        account: 'deploy@staging.example.com:22',
        user: 'deploy',
        host: 'staging.example.com',
        port: '22'
      });
    });

    it('should return empty array when no credentials found', async () => {
      execSync.mockImplementation(() => {
        throw new Error('grep: no matches found');
      });

      const result = await listCredentials();

      expect(result).toEqual([]);
    });

    it('should never include password field in results', async () => {
      const mockOutput = '"acct"<blob>="user@host.com:22"';
      execSync.mockReturnValue(mockOutput);

      const result = await listCredentials();

      expect(result[0]).not.toHaveProperty('password');
      expect(Object.keys(result[0])).toEqual(['account', 'user', 'host', 'port']);
    });

    it('should handle malformed account strings', async () => {
      const mockOutput = `
        "acct"<blob>="root@10.11.2.7:22"
        "acct"<blob>="invalid-account-format"
        "acct"<blob>="admin@server.example.com:2222"
      `;
      execSync.mockReturnValue(mockOutput);

      const result = await listCredentials();

      expect(result).toHaveLength(2);
      expect(result[0].account).toBe('root@10.11.2.7:22');
      expect(result[1].account).toBe('admin@server.example.com:2222');
    });

    it('should handle security command failures gracefully', async () => {
      execSync.mockImplementation(() => {
        throw new Error('security: command not found');
      });

      const result = await listCredentials();

      expect(result).toEqual([]);
    });
  });
});
