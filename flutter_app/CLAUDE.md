# MCP File Manager - Claude Code Instructions

This file provides mandatory instructions for Claude Code when working on this Flutter project.

## Project Overview

MCP File Manager is a Flutter desktop application for managing files on remote SSH servers via the MCP SSH Manager server. It provides a dual-pane file browser interface for transferring files between local and remote systems.

## Architecture

```
lib/
├── main.dart                    # App entry point
├── mcp/
│   └── mcp_client.dart         # MCP WebSocket client and data models
├── models/
│   └── app_settings.dart       # Settings and editor configurations
├── providers/
│   ├── connection_provider.dart # MCP connection state
│   ├── file_browser_provider.dart # File browser state and operations
│   ├── settings_provider.dart   # App settings state
│   └── transfer_provider.dart   # File transfer queue management
├── screens/
│   └── home_screen.dart         # Main application screen
├── services/
│   ├── config_service.dart      # Server configuration management
│   ├── embedded_server_service.dart # Embedded MCP server
│   ├── file_opener_service.dart # File opening with editors
│   ├── file_sync_service.dart   # File sync between local/remote
│   ├── file_watcher_service.dart # File change monitoring
│   └── settings_service.dart    # Persistent settings storage
└── widgets/
    ├── advanced_settings_dialog.dart
    ├── connection_dialog.dart
    ├── file_browser_panel.dart
    ├── file_list_view.dart
    ├── local_file_browser.dart
    ├── new_folder_dialog.dart
    ├── remote_file_browser.dart
    ├── rename_dialog.dart
    ├── server_selector.dart
    ├── server_sidebar.dart
    ├── settings_dialog.dart
    └── transfer_panel.dart
```

---

## MANDATORY TESTING REQUIREMENTS

### RULE 1: Every New Feature MUST Have Tests

**This is NON-NEGOTIABLE.** When adding ANY new functionality:

1. Write the feature code in `lib/`
2. Write corresponding tests in `test/`
3. Run `flutter test` to verify all tests pass
4. Only then commit the changes

### RULE 2: Test File Location Mirrors Source File

Tests MUST follow this exact structure:

| Source File | Test File |
|-------------|-----------|
| `lib/models/foo.dart` | `test/unit/models/foo_test.dart` |
| `lib/mcp/bar.dart` | `test/unit/mcp/bar_test.dart` |
| `lib/providers/baz.dart` | `test/unit/providers/baz_test.dart` |
| `lib/services/qux.dart` | `test/unit/services/qux_test.dart` |
| `lib/widgets/widget.dart` | `test/widget/widgets/widget_test.dart` |
| `lib/screens/screen.dart` | `test/widget/screens/screen_test.dart` |

### RULE 3: Test File Structure

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_file_manager/path/to/source.dart';

// Import mocks if needed
import '../../mocks/mock_mcp_client.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('ClassName', () {
    // Setup/teardown if needed
    late SomeClass instance;

    setUp(() {
      instance = SomeClass();
    });

    tearDown(() {
      instance.dispose();
    });

    group('methodName', () {
      test('should do X when Y', () {
        // Arrange
        final input = 'test';

        // Act
        final result = instance.method(input);

        // Assert
        expect(result, expectedValue);
      });

      test('should throw error when invalid input', () {
        expect(() => instance.method(null), throwsArgumentError);
      });
    });
  });
}
```

### RULE 4: Test Naming Convention

- Test files: `{source_file}_test.dart`
- Test groups: `group('ClassName', () { ... })`
- Sub-groups for methods: `group('methodName', () { ... })`
- Test cases: `test('should {expected behavior} when {condition}', () { ... })`

### RULE 5: Minimum Test Coverage

For each new class/feature, test:

1. **Constructors** - Default values, required parameters
2. **Public methods** - Happy path and error cases
3. **State changes** - Before and after
4. **Edge cases** - Empty, null, boundary values
5. **Error handling** - Exceptions, error states

### RULE 6: Use Mocks from test/mocks/

Available mocks:
- `MockMcpClient` - Mock MCP client for testing without server
- Use `test_helpers.dart` for common test utilities
- Use `test_data.dart` for sample fixtures

---

## Test Categories

### Unit Tests (`test/unit/`)

Pure Dart logic tests without Flutter dependencies:
- Models (serialization, validation, computed properties)
- Providers (state management, business logic)
- Services (file operations, network calls)
- MCP client (protocol handling, data parsing)

```bash
# Run only unit tests
flutter test test/unit/
```

### Widget Tests (`test/widget/`)

UI component tests with mocked dependencies:
- Widget rendering
- User interactions (tap, scroll, input)
- State changes reflected in UI
- Error states and loading states

```bash
# Run only widget tests
flutter test test/widget/
```

### Integration Tests (`test/integration/`)

Full workflow tests with mocked MCP server:
- Complete user flows
- Multi-component interactions
- End-to-end scenarios

```bash
# Run all tests
flutter test
```

---

## Before Committing Checklist

1. [ ] Run `flutter test` - ALL tests must pass
2. [ ] New code has corresponding tests
3. [ ] Test file location follows the naming convention
4. [ ] No `skip` or `TODO` tests without issue reference
5. [ ] Mocks are updated if interface changed

---

## Commands

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/unit/models/app_settings_test.dart

# Run tests matching a pattern
flutter test --name "should create"

# Run tests with verbose output
flutter test --reporter expanded
```

---

## Example: Adding a New Feature

### Step 1: Create the feature

```dart
// lib/services/new_feature_service.dart
class NewFeatureService {
  Future<String> doSomething(String input) async {
    if (input.isEmpty) {
      throw ArgumentError('Input cannot be empty');
    }
    return 'Result: $input';
  }
}
```

### Step 2: Create the test file

```dart
// test/unit/services/new_feature_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_file_manager/services/new_feature_service.dart';

void main() {
  group('NewFeatureService', () {
    late NewFeatureService service;

    setUp(() {
      service = NewFeatureService();
    });

    group('doSomething', () {
      test('should return formatted result when input is valid', () async {
        final result = await service.doSomething('test');
        expect(result, 'Result: test');
      });

      test('should throw ArgumentError when input is empty', () {
        expect(
          () => service.doSomething(''),
          throwsArgumentError,
        );
      });
    });
  });
}
```

### Step 3: Run tests

```bash
flutter test test/unit/services/new_feature_service_test.dart
```

### Step 4: Commit

```bash
git add lib/services/new_feature_service.dart
git add test/unit/services/new_feature_service_test.dart
git commit -m "feat: add NewFeatureService with tests"
```

---

## Icons

This project uses the `hugeicons` package for icons. Use `HugeIcon` widget with `HugeIcons.strokeRounded*` constants.

```dart
HugeIcon(
  icon: HugeIcons.strokeRoundedFolder01,
  size: 20,
  color: colorScheme.primary,
)
```

---

## Code Comments

All code comments MUST be written in English.
