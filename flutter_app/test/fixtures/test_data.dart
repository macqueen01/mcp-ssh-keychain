/// Test fixtures and sample data for tests
library test_data;

/// Sample server configurations
const sampleServersJson = [
  {
    'name': 'production',
    'host': 'prod.example.com',
    'user': 'deploy',
    'port': 22,
    'defaultDir': '/var/www/app',
  },
  {
    'name': 'staging',
    'host': 'staging.example.com',
    'user': 'deploy',
    'port': 22,
    'defaultDir': '/var/www/staging',
  },
  {
    'name': 'development',
    'host': 'dev.example.com',
    'user': 'developer',
    'port': 2222,
  },
];

/// Sample file listing
const sampleFilesJson = {
  'path': '/home/user/project',
  'files': [
    {
      'name': 'src',
      'isDirectory': true,
      'isLink': false,
      'permissions': 'drwxr-xr-x',
      'size': 4096,
      'modified': '2024-01-15 10:30:00',
    },
    {
      'name': 'README.md',
      'isDirectory': false,
      'isLink': false,
      'permissions': '-rw-r--r--',
      'size': 2048,
      'modified': '2024-01-14 09:00:00',
    },
    {
      'name': 'package.json',
      'isDirectory': false,
      'isLink': false,
      'permissions': '-rw-r--r--',
      'size': 1024,
      'modified': '2024-01-13 08:00:00',
    },
    {
      'name': 'node_modules',
      'isDirectory': true,
      'isLink': true,
      'permissions': 'lrwxrwxrwx',
      'size': 0,
      'modified': '2024-01-12 07:00:00',
    },
  ],
};

/// Sample settings
const sampleSettingsJson = {
  'defaultEditorId': 'vscode',
  'autoOpenAfterDownload': true,
  'tempDownloadPath': '/tmp/mcp_downloads',
  'editorsByExtension': {
    'md': 'typora',
    'json': 'vscode',
  },
};

/// File extensions for testing file type detection
const testFileExtensions = {
  // Text files
  'txt': 'text',
  'md': 'text',
  'log': 'text',
  // Code files
  'js': 'code',
  'ts': 'code',
  'py': 'code',
  'dart': 'code',
  // Config files
  'json': 'config',
  'yaml': 'config',
  'yml': 'config',
  'toml': 'config',
  // Images
  'jpg': 'image',
  'png': 'image',
  'gif': 'image',
  // Archives
  'zip': 'archive',
  'tar': 'archive',
  'gz': 'archive',
  // Documents
  'pdf': 'pdf',
  'doc': 'word',
  'xls': 'excel',
};

/// Sample error messages for testing
const sampleErrorMessages = {
  'connectionFailed': 'Connection failed: ECONNREFUSED',
  'timeout': 'Request timed out after 60 seconds',
  'permissionDenied': 'Permission denied: /root/secret',
  'fileNotFound': 'File not found: /home/user/missing.txt',
  'invalidCredentials': 'Authentication failed: Invalid credentials',
};

/// Sample MCP protocol messages
const sampleMcpMessages = {
  'initializeRequest': {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'initialize',
    'params': {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {
        'name': 'mcp-file-manager',
        'version': '1.0.0',
      },
    },
  },
  'initializeResponse': {
    'jsonrpc': '2.0',
    'id': 1,
    'result': {
      'protocolVersion': '2024-11-05',
      'capabilities': {
        'tools': {},
      },
      'serverInfo': {
        'name': 'mcp-ssh-manager',
        'version': '3.0.0',
      },
    },
  },
  'toolCallRequest': {
    'jsonrpc': '2.0',
    'id': 2,
    'method': 'tools/call',
    'params': {
      'name': 'ssh_list_servers',
      'arguments': {},
    },
  },
  'toolCallResponse': {
    'jsonrpc': '2.0',
    'id': 2,
    'result': {
      'content': [
        {
          'type': 'text',
          'text': '[]',
        },
      ],
    },
  },
  'errorResponse': {
    'jsonrpc': '2.0',
    'id': 3,
    'error': {
      'code': -32600,
      'message': 'Invalid Request',
    },
  },
};
