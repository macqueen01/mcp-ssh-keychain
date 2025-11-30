import 'package:flutter/foundation.dart';
import '../mcp/mcp_client.dart';

/// Provider for managing file browser state
class FileBrowserProvider extends ChangeNotifier {
  final McpClient _client;
  final String serverName;

  String _currentPath = '~';
  List<RemoteFile> _files = [];
  Set<String> _selectedFiles = {};
  bool _isLoading = false;
  String? _error;
  bool _showHidden = false;
  List<String> _pathHistory = [];
  int _historyIndex = -1;

  // Sorting
  FileSortField _sortField = FileSortField.name;
  bool _sortAscending = true;

  // Getters
  String get currentPath => _currentPath;
  List<RemoteFile> get files => _sortedFiles;
  Set<String> get selectedFiles => _selectedFiles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showHidden => _showHidden;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _pathHistory.length - 1;
  FileSortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  FileBrowserProvider({
    required McpClient client,
    required this.serverName,
    String initialPath = '~',
  }) : _client = client {
    _currentPath = initialPath;
    refresh();
  }

  List<RemoteFile> get _sortedFiles {
    final sorted = List<RemoteFile>.from(_files);

    sorted.sort((a, b) {
      // Directories first
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int comparison;
      switch (_sortField) {
        case FileSortField.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case FileSortField.size:
          comparison = a.size.compareTo(b.size);
          break;
        case FileSortField.modified:
          comparison = a.modified.compareTo(b.modified);
          break;
        case FileSortField.type:
          final extA = a.name.split('.').last;
          final extB = b.name.split('.').last;
          comparison = extA.compareTo(extB);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  /// Refresh the current directory
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.listFiles(
        serverName,
        path: _currentPath,
        showHidden: _showHidden,
      );
      _files = result.files;
      _currentPath = result.path;

      // Update history
      if (_pathHistory.isEmpty || _pathHistory[_historyIndex] != _currentPath) {
        // Remove forward history
        if (_historyIndex < _pathHistory.length - 1) {
          _pathHistory = _pathHistory.sublist(0, _historyIndex + 1);
        }
        _pathHistory.add(_currentPath);
        _historyIndex = _pathHistory.length - 1;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Navigate to a directory
  Future<void> navigateTo(String path) async {
    _currentPath = path;
    _selectedFiles.clear();
    await refresh();
  }

  /// Go up one directory
  Future<void> goUp() async {
    if (_currentPath == '/' || _currentPath == '~') return;

    final parts = _currentPath.split('/');
    parts.removeLast();
    final newPath = parts.isEmpty ? '/' : parts.join('/');
    await navigateTo(newPath);
  }

  /// Go back in history
  Future<void> goBack() async {
    if (!canGoBack) return;
    _historyIndex--;
    _currentPath = _pathHistory[_historyIndex];
    _selectedFiles.clear();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.listFiles(
        serverName,
        path: _currentPath,
        showHidden: _showHidden,
      );
      _files = result.files;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Go forward in history
  Future<void> goForward() async {
    if (!canGoForward) return;
    _historyIndex++;
    _currentPath = _pathHistory[_historyIndex];
    _selectedFiles.clear();

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _client.listFiles(
        serverName,
        path: _currentPath,
        showHidden: _showHidden,
      );
      _files = result.files;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Open a file or directory
  Future<void> open(RemoteFile file) async {
    if (file.isDirectory) {
      final newPath = _currentPath == '/'
          ? '/${file.name}'
          : '$_currentPath/${file.name}';
      await navigateTo(newPath);
    } else {
      // TODO: Handle file opening (preview, download, etc.)
    }
  }

  /// Toggle file selection
  void toggleSelection(String fileName) {
    if (_selectedFiles.contains(fileName)) {
      _selectedFiles.remove(fileName);
    } else {
      _selectedFiles.add(fileName);
    }
    notifyListeners();
  }

  /// Select all files
  void selectAll() {
    _selectedFiles = _files.map((f) => f.name).toSet();
    notifyListeners();
  }

  /// Clear selection
  void clearSelection() {
    _selectedFiles.clear();
    notifyListeners();
  }

  /// Toggle hidden files
  void toggleHidden() {
    _showHidden = !_showHidden;
    refresh();
  }

  /// Set sort field
  void setSortField(FileSortField field) {
    if (_sortField == field) {
      _sortAscending = !_sortAscending;
    } else {
      _sortField = field;
      _sortAscending = true;
    }
    notifyListeners();
  }

  /// Create a new directory
  Future<bool> createDirectory(String name) async {
    try {
      final path = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
      final result = await _client.mkdir(serverName, path);
      if (result.success) {
        await refresh();
      }
      return result.success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete selected files
  Future<bool> deleteSelected() async {
    if (_selectedFiles.isEmpty) return false;

    try {
      for (final fileName in _selectedFiles) {
        final file = _files.firstWhere((f) => f.name == fileName);
        final path =
            _currentPath == '/' ? '/$fileName' : '$_currentPath/$fileName';
        await _client.delete(serverName, path, recursive: file.isDirectory);
      }
      _selectedFiles.clear();
      await refresh();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Rename a file
  Future<bool> rename(String oldName, String newName) async {
    try {
      final oldPath =
          _currentPath == '/' ? '/$oldName' : '$_currentPath/$oldName';
      final newPath =
          _currentPath == '/' ? '/$newName' : '$_currentPath/$newName';
      final result = await _client.rename(serverName, oldPath, newPath);
      if (result.success) {
        await refresh();
      }
      return result.success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get full path for a file
  String getFullPath(String fileName) {
    return _currentPath == '/' ? '/$fileName' : '$_currentPath/$fileName';
  }
}

enum FileSortField { name, size, modified, type }
