# MCP File Manager

A Flutter-based file manager application that connects to MCP SSH Manager via WebSocket.
Provides a FileZilla/Transmit-like interface for managing remote files over SSH.

## Features

- **MCP Protocol Compatible**: Uses the Model Context Protocol to communicate with the SSH manager
- **Dual-Pane Interface**: Server list sidebar with file browser panel
- **File Operations**: Browse, create folders, rename, delete files/directories
- **Transfer Queue**: Visual transfer management with progress tracking
- **Cross-Platform**: Works on Windows, macOS, Linux, Web

## Architecture

```
┌─────────────────┐      WebSocket       ┌─────────────────┐       SSH        ┌──────────────┐
│  Flutter App    │ ◄──────────────────► │  MCP SSH Server │ ◄──────────────► │   Remote     │
│  (This App)     │    MCP Protocol      │  (Node.js)      │                  │   Servers    │
└─────────────────┘                      └─────────────────┘                  └──────────────┘
```

## Getting Started

### Prerequisites

- Flutter SDK >= 3.0.0
- Node.js >= 18.0.0 (for the MCP server)

### Setup

1. **Start the MCP HTTP Server**:

```bash
cd /path/to/mcp-ssh-manager
npm install
npm run start:http
```

The server will start on `ws://localhost:3000/mcp`

2. **Run the Flutter App**:

```bash
cd flutter_app
flutter pub get
flutter run
```

### Configuration

Configure your SSH servers in the MCP SSH Manager `.env` file:

```env
SSH_SERVER_MYSERVER_HOST=192.168.1.100
SSH_SERVER_MYSERVER_USER=admin
SSH_SERVER_MYSERVER_KEYPATH=~/.ssh/id_rsa
SSH_SERVER_MYSERVER_PORT=22
```

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── mcp/
│   │   └── mcp_client.dart       # MCP WebSocket client
│   ├── providers/
│   │   ├── connection_provider.dart    # Connection state management
│   │   ├── file_browser_provider.dart  # File browser state
│   │   └── transfer_provider.dart      # Transfer queue management
│   ├── screens/
│   │   └── home_screen.dart      # Main screen
│   └── widgets/
│       ├── connection_dialog.dart
│       ├── file_browser_panel.dart
│       ├── file_list_view.dart
│       ├── new_folder_dialog.dart
│       ├── rename_dialog.dart
│       ├── server_sidebar.dart
│       └── transfer_panel.dart
└── pubspec.yaml
```

## MCP Tools Used

The app uses the following MCP tools:

| Tool | Description |
|------|-------------|
| `ssh_list_servers` | List configured SSH servers |
| `ssh_list_files` | List files in a remote directory |
| `ssh_mkdir` | Create a directory |
| `ssh_delete` | Delete files/directories |
| `ssh_rename` | Rename/move files |
| `ssh_upload` | Upload files |
| `ssh_download` | Download files |
| `ssh_execute` | Execute commands |

## Development

### Adding New Features

1. **New MCP Tools**: Add methods to `mcp_client.dart`
2. **UI Components**: Create widgets in `widgets/`
3. **State Management**: Use Provider pattern in `providers/`

### Building for Production

```bash
# Web
flutter build web

# Desktop
flutter build macos
flutter build windows
flutter build linux
```

## Screenshots

*Coming soon*

## License

MIT License - Same as MCP SSH Manager
