import { getCredential, storeCredentialOOB, deleteCredential, listCredentials } from '../keychain.js';

export const keychainTools = {
  ssh_store_password: {
    description: 'Store SSH password in macOS Keychain using out-of-band native password dialog. User will be prompted with a secure dialog - password is NEVER passed as parameter.',
    inputSchema: {
      type: 'object',
      properties: {
        user: {
          type: 'string',
          description: 'SSH username'
        },
        host: {
          type: 'string',
          description: 'SSH hostname or IP address'
        },
        port: {
          type: 'number',
          description: 'SSH port (default: 22)',
          default: 22
        }
      },
      required: ['user', 'host']
    },
    handler: async (params) => {
      const { user, host, port = 22 } = params;
      
      const result = await storeCredentialOOB(user, host, port);
      
      if (result.success) {
        return {
          success: true,
          message: `Password stored successfully for ${user}@${host}:${port}`
        };
      } else {
        return {
          success: false,
          error: result.error
        };
      }
    }
  },

  ssh_delete_password: {
    description: 'Delete SSH password from macOS Keychain',
    inputSchema: {
      type: 'object',
      properties: {
        user: {
          type: 'string',
          description: 'SSH username'
        },
        host: {
          type: 'string',
          description: 'SSH hostname or IP address'
        },
        port: {
          type: 'number',
          description: 'SSH port (default: 22)',
          default: 22
        }
      },
      required: ['user', 'host']
    },
    handler: async (params) => {
      const { user, host, port = 22 } = params;
      
      const result = await deleteCredential(user, host, port);
      
      if (result.success) {
        return {
          success: true,
          message: `Password deleted successfully for ${user}@${host}:${port}`
        };
      } else {
        return {
          success: false,
          error: result.error
        };
      }
    }
  },

  ssh_list_credentials: {
    description: 'List all SSH credentials stored in macOS Keychain. Returns account information only - passwords are NEVER included.',
    inputSchema: {
      type: 'object',
      properties: {}
    },
    handler: async () => {
      const credentials = await listCredentials();
      
      return {
        success: true,
        count: credentials.length,
        credentials: credentials.map(cred => ({
          account: cred.account,
          user: cred.user,
          host: cred.host,
          port: cred.port
        }))
      };
    }
  }
};
