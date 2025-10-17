# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**bill_manager** is a Flutter mobile application project in early development stages. Currently a basic counter demo template, intended to evolve into a bill management application.

### Technology Stack
- **Language:** Dart (SDK ^3.9.2)
- **Framework:** Flutter (>=3.18.0-18.0.pre.54)
- **State Management:** Currently using StatefulWidget (basic Flutter state management)
- **Testing:** flutter_test framework with WidgetTester
- **Linting:** flutter_lints package with recommended rules

## Development Commands

### Basic Development
```bash
# Install dependencies
flutter pub get

# Run the application
flutter run

# Run in specific platform (Android, iOS, web, etc.)
flutter run -d android

# Hot reload during development (press 'r' in terminal)
flutter pub run

# Hot restart (press 'R' in terminal)
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Run tests in debug mode
flutter test --debug
```

### Code Quality
```bash
# Static analysis and linting
flutter analyze

# Check for dependency updates
flutter pub outdated

# Update dependencies (major versions)
flutter pub upgrade --major-versions

# Update dependencies (safe updates only)
flutter pub upgrade
```

### Build and Deployment
```bash
# Build for release (Android)
flutter build apk --release
flutter build appbundle --release

# Build for release (iOS)
flutter build ios --release

# Clean build cache
flutter clean

# Doctor command to check Flutter setup
flutter doctor
```

## Project Structure

```
bill_manager/
├── lib/
│   └── main.dart                    # Main entry point and app structure
├── test/
│   └── widget_test.dart             # Widget tests for counter functionality
├── android/                         # Android-specific configuration
├── ios/                           # iOS-specific configuration
├── linux/                         # Linux desktop configuration
├── macos/                         # macOS desktop configuration
├── web/                           # Web platform configuration
├── windows/                       # Windows desktop configuration
├── pubspec.yaml                    # Project configuration and dependencies
├── analysis_options.yaml           # Linting and analysis rules
└── .gitignore                     # Git exclusions for Flutter projects
```

## Current Architecture

### App Structure (lib/main.dart)
- **MyApp:** StatelessWidget - Root widget with Material Design theme and MaterialApp setup
- **MyHomePage:** StatefulWidget - Main page widget with counter state management
- **_MyHomePageState:** State management for the counter functionality

### Key Components
- Uses Material Design with deep purple seed color theme
- Basic Scaffold structure with AppBar and FloatingActionButton
- State management via Flutter's built-in StatefulWidget
- Minimal widget tree with Column layout

### Testing (test/widget_test.dart)
- Basic widget testing for counter functionality
- Uses WidgetTester for UI interactions
- Verifies counter state changes and text updates

## Development Guidelines

### Code Organization
- Currently single-file architecture in lib/
- Future structure should consider separation of concerns:
  - Models: Data structures for bills and related entities
  - Services: Business logic and data management
  - Widgets: Reusable UI components
  - Screens: Main application screens
  - Utils: Helper functions and constants

### State Management Considerations
- Current: Basic StatefulWidget approach
- Future options to consider for bill management app:
  - Provider: For simple state sharing
  - Riverpod: Improved dependency injection
  - BLoC/Cubit: Complex state management with streams
  - Flutter's built-in ValueNotifier for simple reactive values

### Data Persistence
- No current data persistence implementation
- Future considerations:
  - SQLite (sqflite) for local bill storage
  - Hive for simple key-value storage
  - Shared preferences for app settings
  - Cloud storage options for cross-device sync

### Navigation
- Currently single-screen application
- Future navigation considerations:
  - Named routes for simple navigation
  - GoRouter for complex routing scenarios
  - Bottom navigation bar for main app sections

## Dependencies and Configuration

### Current Dependencies
- **cupertino_icons:** ^1.0.8 - iOS-style icons
- **flutter_test:** - Built-in testing framework
- **flutter_lints:** ^5.0.0 - Recommended linting rules

### Common Dependencies to Consider
```yaml
# State Management
provider: ^6.0.0
riverpod: ^2.4.0
flutter_bloc: ^8.1.0

# Local Storage
sqflite: ^2.3.0
shared_preferences: ^2.2.0
hive: ^2.2.0

# Navigation
go_router: ^12.0.0

# UI Components
flutter_staggered_grid_view: ^0.7.0
flutter_svg: ^2.0.0

# Utility packages
intl: ^0.19.0  # Internationalization
path_provider: ^2.1.0  # File system paths
```

### Platform-Specific Setup
- **Android:** Review android/build.gradle.kts and android/app/build.gradle.kts for build configurations
- **iOS:** Review ios/Runner.xcodeproj for iOS-specific settings
- **Web:** Review web/index.html for web-specific configuration

## Testing Strategy

### Current Testing
- Basic widget testing using WidgetTester
- Tests counter functionality with tap gestures
- Verifies text widget updates after state changes

### Recommended Testing Expansion
- Unit tests for business logic
- Integration tests for user flows
- Mock services for data dependencies
- Golden tests for UI consistency
- Platform-specific testing (iOS, Android, Web)

## Platform Support

### Currently Configured Platforms
- ✅ Android
- ✅ iOS
- ✅ Linux
- ✅ macOS
- ✅ Windows
- ✅ Web

### Platform-Specific Commands
```bash
# Build for specific platforms
flutter build android --release
flutter build ios --release
flutter build linux --release
flutter build windows --release
flutter build web --release
```

## Development Workflow

### New Feature Development
1. Create feature branch from main/master
2. Implement feature with proper state management
3. Add comprehensive tests
4. Run `flutter analyze` to ensure code quality
5. Run `flutter test` to ensure all tests pass
6. Test on target platforms before merging

### Code Review Guidelines
- Follow Dart/Flutter style guide
- Ensure proper error handling
- Include appropriate comments for complex logic
- Verify widget tree efficiency
- Check memory usage and state management patterns

## Troubleshooting

### Common Issues
- **Hot reload not working:** Try `flutter clean` and rebuild
- **Dependency conflicts:** Run `flutter pub get` after pubspec.yaml changes
- **Platform-specific build errors:** Check platform-specific configuration files
- **Lint errors:** Review analysis_options.yaml and adjust rules if needed

### Performance Considerations
- Use const constructors where possible
- Implement proper widget lifecycle management
- Consider using ListView.builder for large lists
- Implement proper image loading and caching
- Monitor memory usage and avoid widget rebuilds