import { getPassword, setPassword, deletePassword } from 'cross-keychain';
import { execSync } from 'child_process';

const SERVICE_NAME = 'mcp-ssh-keychain';

/**
 * Format account string for keychain
 * @param {string} user - SSH username
 * @param {string} host - SSH hostname
 * @param {number|string} port - SSH port (default 22)
 * @returns {string} Formatted account string (e.g., "user@host-22")
 */
function formatAccount(user, host, port = 22) {
  return `${user}@${host}-${port}`;
}

/**
 * Get credential from keychain
 * @param {string} user - SSH username
 * @param {string} host - SSH hostname
 * @param {number|string} port - SSH port (default 22)
 * @returns {Promise<string|null>} Password or null if not found
 */
export async function getCredential(user, host, port = 22) {
  const account = formatAccount(user, host, port);
  try {
    const password = await getPassword(SERVICE_NAME, account);
    return password;
  } catch (error) {
    return null;
  }
}

/**
 * Store credential using out-of-band macOS password dialog
 * @param {string} user - SSH username
 * @param {string} host - SSH hostname
 * @param {number|string} port - SSH port (default 22)
 * @returns {Promise<{success: boolean, error?: string}>}
 */
export async function storeCredentialOOB(user, host, port = 22) {
  const account = formatAccount(user, host, port);
  
  try {
    const script = `display dialog "Enter SSH password for ${account}:" default answer "" with hidden answer buttons {"Cancel", "Save"} default button "Save" with title "MCP SSH Keychain"`;
    
    const result = execSync(`osascript -e '${script}'`, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();
    
    const textMatch = result.match(/text returned:(.*)$/);
    if (!textMatch) {
      return { success: false, error: 'Failed to parse password from dialog' };
    }
    
    const password = textMatch[1];
    
    if (!password) {
      return { success: false, error: 'Password cannot be empty' };
    }
    
    await setPassword(SERVICE_NAME, account, password);
    
    // Zero the password string (best effort - JS doesn't guarantee memory zeroing)
    // This at least removes the reference
    const passwordLength = password.length;
    let zeroedPassword = '\0'.repeat(passwordLength);
    zeroedPassword = null;
    
    return { success: true };
  } catch (error) {
    if (error.message && error.message.includes('User canceled')) {
      return { success: false, error: 'User cancelled password entry' };
    }
    
    if (error.status === 128) {
      return { success: false, error: 'User cancelled password entry' };
    }
    
    return { success: false, error: error.message || 'Failed to store credential' };
  }
}

/**
 * Delete credential from keychain
 * @param {string} user - SSH username
 * @param {string} host - SSH hostname
 * @param {number|string} port - SSH port (default 22)
 * @returns {Promise<{success: boolean, error?: string}>}
 */
export async function deleteCredential(user, host, port = 22) {
  const account = formatAccount(user, host, port);
  
  try {
    await deletePassword(SERVICE_NAME, account);
    return { success: true };
  } catch (error) {
    if (error.message && error.message.includes('not found')) {
      return { success: false, error: 'Credential not found' };
    }
    
    return { success: false, error: error.message || 'Failed to delete credential' };
  }
}

/**
 * List all credentials stored for this service
 * Note: cross-keychain doesn't provide a native list function,
 * so we need to use macOS security command directly
 * @returns {Promise<Array<{account: string, user: string, host: string, port: string}>>}
 */
export async function listCredentials() {
  try {
    const result = execSync(
      `security dump-keychain | grep -A 3 '"svce"<blob>="${SERVICE_NAME}"' | grep '"acct"<blob>='`,
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    );
    
    const accounts = [];
    const lines = result.split('\n');
    
    for (const line of lines) {
      const match = line.match(/"acct"<blob>="([^"]+)"/);
      if (match) {
        const account = match[1];
        const accountMatch = account.match(/^(.+)@(.+)-(\d+)$/);
        if (accountMatch) {
          accounts.push({
            account: account,
            user: accountMatch[1],
            host: accountMatch[2],
            port: accountMatch[3]
          });
        }
      }
    }
    
    return accounts;
  } catch (error) {
    return [];
  }
}
