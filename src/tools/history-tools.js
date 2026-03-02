import { queryHistory, getCommandDetail } from '../history.js';

export const historyTools = {
  ssh_history: {
    description: 'Query SSH command execution history with filters. List view excludes stdout/stderr for performance. Use detail view to get full output.',
    inputSchema: {
      type: 'object',
      properties: {
        host: { 
          type: 'string', 
          description: 'Filter by remote host' 
        },
        user: { 
          type: 'string', 
          description: 'Filter by SSH user' 
        },
        commandFilter: { 
          type: 'string', 
          description: 'Filter by command text (partial match)' 
        },
        session_id: { 
          type: 'string', 
          description: 'Filter by session ID' 
        },
        limit: { 
          type: 'number', 
          description: 'Maximum number of results (default: 100)',
          default: 100
        },
        detail_id: {
          type: 'string',
          description: 'Get full details for specific command ID (includes stdout/stderr)'
        }
      }
    },
    handler: async (params) => {
      if (params.detail_id) {
        const detail = getCommandDetail(params.detail_id);
        if (!detail) {
          return {
            success: false,
            error: `Command not found: ${params.detail_id}`
          };
        }
        return {
          success: true,
          mode: 'detail',
          command: detail
        };
      }

      const filters = {
        host: params.host,
        user: params.user,
        commandFilter: params.commandFilter,
        session_id: params.session_id
      };

      const results = queryHistory(filters, params.limit || 100);

      return {
        success: true,
        mode: 'list',
        count: results.length,
        commands: results
      };
    }
  }
};
