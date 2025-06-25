# Automatic Versioning Strategy for MarketSnap

## Overview

This document outlines the comprehensive automatic versioning strategy implemented for MarketSnap, including automatic version number generation during CI/CD builds and version display throughout the application.

## Versioning Strategy

### Version Format

MarketSnap uses semantic versioning with enhanced build information:

```
<major>.<minor>.<patch>+<build_number>.<commit_sha>
```

**Example:** `1.0.0+42.a1b2c3d`

### Version Components

| Component | Description | Example | Source |
|-----------|-------------|---------|--------|
| **Major** | Breaking changes, major features | `1` | Manual in `pubspec.yaml` |
| **Minor** | New features, backwards compatible | `0` | Manual in `pubspec.yaml` |
| **Patch** | Bug fixes, patches | `0` | Manual in `pubspec.yaml` |
| **Build Number** | GitHub Actions run number | `42` | Automatic - `${{ github.run_number }}` |
| **Commit SHA** | Short commit identifier | `a1b2c3d` | Automatic - First 7 chars of `${{ github.sha }}` |

### Version Generation Process

#### 1. **Manual Version Updates**
Developers manually update the base version (`major.minor.patch`) in `pubspec.yaml` when:
- **Major**: Breaking changes or significant rewrites
- **Minor**: New features added
- **Patch**: Bug fixes or minor improvements

#### 2. **Automatic Build Information**
During GitHub Actions CI/CD pipeline:
- **Build Number**: Incremented automatically using GitHub run number
- **Commit SHA**: Extracted from the current commit hash
- **Full Version**: Combined automatically during build process

## Implementation

### GitHub Actions Integration

#### Version Update Step
Located in `.github/workflows/deploy.yml`:

```yaml
- name: Update version number automatically
  run: |
    # Extract base version from pubspec.yaml
    CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
    
    # Generate build number with run number and commit SHA
    GITHUB_RUN_NUM=${{ github.run_number }}
    COMMIT_SHA="${{ github.sha }}"
    SHORT_SHA=$(echo $COMMIT_SHA | cut -c1-7)
    NEW_BUILD_NUMBER="${GITHUB_RUN_NUM}.${SHORT_SHA}"
    
    # Update pubspec.yaml
    NEW_VERSION="${CURRENT_VERSION}+${NEW_BUILD_NUMBER}"
    sed -i "s/^version:.*/version: $NEW_VERSION/" pubspec.yaml
```

#### Version Information File
Generates `version_info.txt` with comprehensive build information:

```
MarketSnap Release Information
=============================
Version: 1.0.0+42.a1b2c3d
Base Version: 1.0.0
Build Number: 42.a1b2c3d
GitHub Run: 42
Commit SHA: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
Short SHA: a1b2c3d
Build Date: 2024-01-15 14:30:22 UTC
Branch: main
Workflow: CI/CD Pipeline for MarketSnap
```

### Firebase App Distribution Integration

The version information file is automatically attached to Firebase App Distribution releases as release notes, providing testers with:
- Exact version information
- Build metadata
- Commit traceability
- Build timestamp

## Version Display in Application

### Package Integration

**Dependency Added:**
```yaml
dependencies:
  package_info_plus: ^8.1.0
```

### Version Display Components

#### 1. **VersionDisplayWidget**
Main widget for displaying version information:

```dart
VersionDisplayWidget(
  showBuildNumber: true,
  alignment: Alignment.center,
  style: AppTypography.caption.copyWith(
    color: AppColors.soilTaupe.withValues(alpha: 0.7),
    fontSize: 10,
  ),
)
```

**Features:**
- Configurable build number display
- Custom styling support
- Automatic loading and error handling
- Responsive alignment options

#### 2. **CompactVersionDisplay**
Positioned widget for screen corners:

```dart
CompactVersionDisplay(
  position: Alignment.bottomLeft,
  padding: EdgeInsets.all(AppSpacing.sm),
)
```

**Features:**
- Absolute positioning
- Minimal footprint
- Subtle appearance

#### 3. **DebugVersionDisplay**
Development mode detailed information:

```dart
DebugVersionDisplay()
```

**Features:**
- App name and package information
- Version and build details
- Build signature for verification
- Debug-only visibility

### Display Locations

#### 1. **Auth Welcome Screen**
- **Location**: Bottom of screen, above terms
- **Purpose**: Version visibility for all users
- **Implementation**: Standard `VersionDisplayWidget`

#### 2. **Camera Preview Screen**
- **Location**: Bottom left corner
- **Purpose**: Subtle reference for authenticated users
- **Implementation**: `CompactVersionDisplay`

#### 3. **Development Demo Mode**
- **Location**: Bottom left corner overlay
- **Purpose**: Comprehensive debug information
- **Implementation**: `DebugVersionDisplay`

## Version Tracking Benefits

### Development Benefits

1. **Build Traceability**
   - Every APK/IPA can be traced to exact commit
   - GitHub run number provides build sequence
   - Timestamp shows when build was created

2. **Testing Coordination**
   - Testers can report issues with exact version
   - Developers can quickly identify code state
   - Firebase App Distribution shows version history

3. **Deployment Tracking**
   - Version increments automatically on each release
   - No manual version management required
   - Consistent versioning across all platforms

### User Benefits

1. **Support Assistance**
   - Users can easily report their version
   - Support team can identify user's build
   - Faster troubleshooting and bug resolution

2. **Update Awareness**
   - Clear version display shows current state
   - Users can verify they have latest version
   - Visual confirmation of successful updates

## Version Management Guidelines

### Manual Version Updates

#### When to Increment Major Version (x.0.0)
- Breaking API changes
- Major feature overhauls
- Significant UI/UX redesigns
- Database schema changes requiring migration

#### When to Increment Minor Version (1.x.0)
- New features added
- New screens or major functionality
- Backwards-compatible API additions
- Significant performance improvements

#### When to Increment Patch Version (1.0.x)
- Bug fixes
- Security patches
- Minor UI improvements
- Performance optimizations
- Dependency updates

### Automatic Build Number Management

**Build numbers increment automatically and should never be manually managed.**

- **GitHub Run Number**: Provides sequential build tracking
- **Commit SHA**: Ensures exact code traceability
- **Combined**: Creates unique, traceable version identifier

## Troubleshooting

### Common Issues

#### 1. **Version Not Displaying**
**Symptoms:** Version widget shows "Version unavailable"
**Causes:**
- `package_info_plus` not properly initialized
- Platform-specific configuration missing
- Build configuration issues

**Solutions:**
```dart
// Ensure proper error handling
try {
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  // Use packageInfo
} catch (e) {
  debugPrint('Package info error: $e');
  // Fallback handling
}
```

#### 2. **Build Number Not Updating**
**Symptoms:** Same build number across different builds
**Causes:**
- GitHub Actions versioning step not running
- Cached pubspec.yaml not being updated
- Build pipeline configuration errors

**Solutions:**
- Verify GitHub Actions logs
- Check versioning step execution
- Clear build caches if necessary

#### 3. **Version Format Issues**
**Symptoms:** Malformed version strings
**Causes:**
- Sed command execution errors
- Special characters in commit SHA
- Platform-specific shell differences

**Solutions:**
- Test versioning script locally
- Add additional validation steps
- Use alternative string manipulation methods

### Debug Verification

#### Local Testing
```bash
# Check current version
grep "^version:" pubspec.yaml

# Test package info access
flutter packages get
flutter run --debug
```

#### CI/CD Testing
```bash
# Verify versioning step in GitHub Actions
# Check workflow logs for version update output
# Confirm version_info.txt generation
```

### Emergency Procedures

#### Rollback Version
If versioning causes issues:

1. **Revert pubspec.yaml**
   ```bash
   git checkout HEAD~1 -- pubspec.yaml
   ```

2. **Manual Version Override**
   ```yaml
   # In pubspec.yaml
   version: 1.0.0+manual.override
   ```

3. **Disable Auto-versioning**
   ```yaml
   # Comment out versioning step in GitHub Actions
   # - name: Update version number automatically
   ```

## Future Enhancements

### Potential Improvements

1. **Semantic Version Automation**
   - Analyze commit messages for auto-increment hints
   - Implement conventional commits for version bumping
   - Add version tags to Git repository

2. **Release Notes Generation**
   - Auto-generate release notes from commits
   - Include feature summaries in version info
   - Link to GitHub releases and changelogs

3. **Version Analytics**
   - Track version distribution among users
   - Monitor update adoption rates
   - Collect version-specific crash reports

4. **Advanced Version Display**
   - Settings screen with detailed version info
   - Update notification integration
   - Version comparison features

---

*This versioning strategy ensures consistent, traceable, and informative version management across the entire MarketSnap application lifecycle.* 